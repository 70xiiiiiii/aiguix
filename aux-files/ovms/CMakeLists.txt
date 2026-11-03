# CMake build for OpenVINO Model Server and the parts of its MediaPipe fork
# that it uses, replacing the upstream Bazel build for GNU Guix.
#
# Upstream configuration reproduced here: MEDIAPIPE_DISABLE=0,
# MEDIAPIPE_DISABLE_GPU=1, PYTHON_DISABLE=1, CLOUD_DISABLE=1.

cmake_minimum_required(VERSION 3.21)
project(ovms LANGUAGES C CXX)

set(OVMS_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}" CACHE PATH
  "OpenVINO Model Server source tree")
set(MEDIAPIPE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/mediapipe" CACHE PATH
  "Source tree of the openvinotoolkit/mediapipe fork")
option(OVMS_TFTENSOR
  "Support TensorFlow tensors in MediaPipe graphs (needs TensorFlow)" OFF)

get_filename_component(MEDIAPIPE_SOURCE_DIR "${MEDIAPIPE_SOURCE_DIR}" ABSOLUTE)
if(NOT EXISTS "${MEDIAPIPE_SOURCE_DIR}/mediapipe/framework")
  message(FATAL_ERROR "MEDIAPIPE_SOURCE_DIR must point to the MediaPipe fork")
endif()
if(OVMS_TFTENSOR)
  message(FATAL_ERROR "OVMS_TFTENSOR needs the TensorFlow framework library,"
    " which this build cannot use yet")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

find_package(Threads REQUIRED)
find_package(PkgConfig REQUIRED)
find_package(absl CONFIG REQUIRED)
find_package(Protobuf CONFIG REQUIRED)
find_package(gRPC CONFIG REQUIRED)
find_package(re2 CONFIG REQUIRED)
find_package(glog CONFIG REQUIRED)
find_package(OpenCV REQUIRED COMPONENTS core imgproc imgcodecs)
find_package(Eigen3 REQUIRED)
find_package(OpenVINO REQUIRED COMPONENTS Runtime)
find_package(OpenVINOGenAI REQUIRED)
# Before Drogon, whose FindBrotli.cmake defines other target names.
find_package(httplib CONFIG REQUIRED)
# gRPC adds a Findc-ares.cmake that would define c-ares::cares a second
# time when Trantor, used by Drogon, looks for c-ares.
list(FILTER CMAKE_MODULE_PATH EXCLUDE REGEX "/grpc/modules$")
find_package(Drogon CONFIG REQUIRED)
find_package(prometheus-cpp CONFIG REQUIRED)
find_package(spdlog CONFIG REQUIRED)
find_package(fmt CONFIG REQUIRED)
find_package(cxxopts CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)
# RapidJSONConfig.cmake is too old for CMake 4; the library is header-only.
find_path(RAPIDJSON_INCLUDE_DIR rapidjson/rapidjson.h REQUIRED)
find_package(CURL REQUIRED)
find_package(OpenSSL REQUIRED)
find_package(OpenCL REQUIRED)
pkg_check_modules(LIBGIT2 REQUIRED IMPORTED_TARGET libgit2)
pkg_check_modules(LIBVA REQUIRED IMPORTED_TARGET libva)
pkg_check_modules(UUID REQUIRED IMPORTED_TARGET uuid)
find_library(MINITRACE_LIBRARY minitrace REQUIRED)
find_path(MINITRACE_INCLUDE_DIR minitrace.h REQUIRED)
find_path(DR_LIBS_INCLUDE_DIR dr_wav.h REQUIRED)
find_path(STB_INCLUDE_DIR stb_image.h REQUIRED)
# Only for the TfLiteTensor type in some core calculators.
find_path(TFLITE_INCLUDE_DIR tensorflow/lite/interpreter.h REQUIRED)

set(GEN_DIR "${CMAKE_CURRENT_BINARY_DIR}/gen")
file(MAKE_DIRECTORY "${GEN_DIR}")

# Compile PROTOS (paths relative to ROOT) into C++ sources in GEN_DIR and
# return the generated sources in OUT.
function(ovms_protoc out root)
  cmake_parse_arguments(ARG "" "" "PROTOS;IMPORTS" ${ARGN})
  set(srcs)
  set(hdrs)
  foreach(proto IN LISTS ARG_PROTOS)
    string(REGEX REPLACE "\\.proto$" "" stem "${proto}")
    list(APPEND srcs "${GEN_DIR}/${stem}.pb.cc")
    list(APPEND hdrs "${GEN_DIR}/${stem}.pb.h")
  endforeach()
  set(include_args "-I${root}")
  foreach(dir IN LISTS ARG_IMPORTS)
    list(APPEND include_args "-I${dir}")
  endforeach()
  add_custom_command(
    OUTPUT ${srcs} ${hdrs}
    COMMAND protobuf::protoc ${include_args} "--cpp_out=${GEN_DIR}"
            ${ARG_PROTOS}
    WORKING_DIRECTORY "${root}"
    DEPENDS protobuf::protoc
    COMMENT "Generating C++ code from protos in ${root}"
    VERBATIM)
  set(${out} ${srcs} PARENT_SCOPE)
endfunction()

# Return the files in LIST that do not define main().
function(ovms_without_main out)
  set(result)
  foreach(file IN LISTS ARGN)
    file(STRINGS "${file}" mains REGEX "^int main\\(")
    if(NOT mains)
      list(APPEND result "${file}")
    endif()
  endforeach()
  set(${out} ${result} PARENT_SCOPE)
endfunction()

set(COMMON_DEFINES
  MEDIAPIPE_DISABLE=0
  MEDIAPIPE_DISABLE_GPU=1
  PYTHON_DISABLE=1
  CLOUD_DISABLE=1
  TFTENSOR_DISABLE=1
  OVMS_DUMP_TO_FILE=0
  GLOG_USE_GLOG_EXPORT)

set(COMMON_LIBS
  absl::base absl::log absl::log_internal_check_op absl::log_initialize
  absl::status absl::statusor absl::strings absl::str_format
  absl::flat_hash_map absl::flat_hash_set absl::node_hash_map
  absl::synchronization absl::time absl::flags absl::flags_parse
  absl::any_invocable absl::cord absl::random_random absl::span
  protobuf::libprotobuf glog::glog re2::re2
  ${OpenCV_LIBS} Eigen3::Eigen Threads::Threads)

### MediaPipe

file(GLOB_RECURSE MP_PROTOS RELATIVE "${MEDIAPIPE_SOURCE_DIR}"
  "${MEDIAPIPE_SOURCE_DIR}/mediapipe/framework/*.proto"
  "${MEDIAPIPE_SOURCE_DIR}/mediapipe/calculators/*.proto"
  "${MEDIAPIPE_SOURCE_DIR}/mediapipe/gpu/*.proto"
  "${MEDIAPIPE_SOURCE_DIR}/mediapipe/util/*.proto")
# The Geti protos define the KServe messages a second time.
list(FILTER MP_PROTOS EXCLUDE REGEX
  "test|/calculators/(tensorflow|openvino|ovms|geti)/")
ovms_protoc(MP_PROTO_SRCS "${MEDIAPIPE_SOURCE_DIR}" PROTOS ${MP_PROTOS})

file(GLOB_RECURSE MP_SRCS
  "${MEDIAPIPE_SOURCE_DIR}/mediapipe/framework/*.cc"
  "${MEDIAPIPE_SOURCE_DIR}/mediapipe/calculators/core/*.cc")
list(FILTER MP_SRCS EXCLUDE REGEX
  "test|gl[^/]*\\.cc$|android|apple|metal|/motion/|_ios|_template\\.cc$")
# Bazel uses the std::thread thread pool only on Windows.
list(FILTER MP_SRCS EXCLUDE REGEX "threadpool_std_thread_impl\\.cc$")
ovms_without_main(MP_SRCS ${MP_SRCS})
# Used by the framework also without GPU support.
foreach(file
    gpu/gpu_buffer.cc gpu/gpu_buffer_format.cc gpu/gpu_buffer_storage.cc
    gpu/gpu_buffer_storage_image_frame.cc
    util/cpu_util.cc util/header_util.cc
    util/resource_util.cc util/resource_util_default.cc)
  list(APPEND MP_SRCS "${MEDIAPIPE_SOURCE_DIR}/mediapipe/${file}")
endforeach()

# An object library, so that every calculator and stream handler is linked
# and registers itself, like Bazel's alwayslink.
add_library(mediapipe OBJECT ${MP_SRCS} ${MP_PROTO_SRCS})
target_include_directories(mediapipe PUBLIC
  "${MEDIAPIPE_SOURCE_DIR}" "${GEN_DIR}")
target_include_directories(mediapipe PRIVATE "${TFLITE_INCLUDE_DIR}")
target_compile_definitions(mediapipe PUBLIC ${COMMON_DEFINES})
target_compile_options(mediapipe PRIVATE -Wno-deprecated-declarations)
target_link_libraries(mediapipe PUBLIC ${COMMON_LIBS})

### OpenVINO Model Server

file(GLOB_RECURSE OVMS_PROTOS RELATIVE "${OVMS_SOURCE_DIR}"
  "${OVMS_SOURCE_DIR}/src/*.proto")
list(FILTER OVMS_PROTOS EXCLUDE REGEX "^src/(test|python|example)/")
ovms_protoc(OVMS_PROTO_SRCS "${OVMS_SOURCE_DIR}"
  PROTOS ${OVMS_PROTOS} IMPORTS "${MEDIAPIPE_SOURCE_DIR}")

set(KFS_GRPC_PROTO src/kfserving_api/grpc_predict_v2.proto)
set(KFS_GRPC_SRCS "${GEN_DIR}/src/kfserving_api/grpc_predict_v2.grpc.pb.cc")
add_custom_command(
  OUTPUT ${KFS_GRPC_SRCS}
         "${GEN_DIR}/src/kfserving_api/grpc_predict_v2.grpc.pb.h"
  COMMAND protobuf::protoc "-I${OVMS_SOURCE_DIR}" "--grpc_out=${GEN_DIR}"
          "--plugin=protoc-gen-grpc=$<TARGET_FILE:gRPC::grpc_cpp_plugin>"
          ${KFS_GRPC_PROTO}
  WORKING_DIRECTORY "${OVMS_SOURCE_DIR}"
  DEPENDS protobuf::protoc gRPC::grpc_cpp_plugin
  VERBATIM)

file(GLOB_RECURSE OVMS_SRCS
  "${OVMS_SOURCE_DIR}/src/*.cpp" "${OVMS_SOURCE_DIR}/src/*.cc")
list(FILTER OVMS_SRCS EXCLUDE REGEX
  "/src/(test|python|example|custom_nodes)/")
list(FILTER OVMS_SRCS EXCLUDE REGEX
  "windows|/(azure|s3|gcs)[^/]*\\.cpp$|py_jinja_template_processor")
# Not built by Bazel either: leftovers marked "#pragma once".
list(FILTER OVMS_SRCS EXCLUDE REGEX
  "/(capi_frontend/serialization|kfs_frontend/kfs_frontend_impl)\\.cpp$")
# Only needed for TensorFlow tensors (OVMS_TFTENSOR).
list(FILTER OVMS_SRCS EXCLUDE REGEX "/tensorflow_type_utils\\.cpp$")
ovms_without_main(OVMS_SRCS ${OVMS_SRCS})

add_executable(ovms
  "${OVMS_SOURCE_DIR}/src/main.cpp"
  ${OVMS_SRCS} ${OVMS_PROTO_SRCS} ${KFS_GRPC_SRCS})
target_include_directories(ovms PRIVATE
  "${OVMS_SOURCE_DIR}" "${OVMS_SOURCE_DIR}/src" "${GEN_DIR}" "${GEN_DIR}/src"
  "${MINITRACE_INCLUDE_DIR}" "${DR_LIBS_INCLUDE_DIR}" "${STB_INCLUDE_DIR}"
  "${RAPIDJSON_INCLUDE_DIR}")
target_compile_definitions(ovms PRIVATE
  SPDLOG_ACTIVE_LEVEL=SPDLOG_LEVEL_TRACE)
target_compile_options(ovms PRIVATE
  -Wall -Wno-unknown-pragmas -Wno-sign-compare -Wno-deprecated-declarations
  -fvisibility=hidden)
target_link_libraries(ovms PRIVATE
  mediapipe
  openvino::runtime openvino::genai
  gRPC::grpc++
  Drogon::Drogon prometheus-cpp::core
  spdlog::spdlog fmt::fmt cxxopts::cxxopts nlohmann_json::nlohmann_json
  httplib::httplib
  CURL::libcurl OpenSSL::SSL OpenSSL::Crypto OpenCL::OpenCL
  PkgConfig::LIBGIT2 PkgConfig::LIBVA PkgConfig::UUID
  "${MINITRACE_LIBRARY}" ${CMAKE_DL_LIBS})
# Like Bazel's optimized build: drop unused sections, among them explicit
# template instantiations that refer to specializations defined elsewhere.
target_compile_options(mediapipe PRIVATE -ffunction-sections -fdata-sections)
target_compile_options(ovms PRIVATE -ffunction-sections -fdata-sections)
target_link_options(ovms PRIVATE -Wl,--gc-sections)

install(TARGETS ovms RUNTIME DESTINATION bin)
