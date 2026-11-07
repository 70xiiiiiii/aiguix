;;; aiguix --- Guix channel for packages written by or with AI
;;; Copyright © 2026 Goran Vukoman <g@odyss3us.net>
;;;
;;; This file is part of aiguix.
;;;
;;; aiguix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; aiguix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with aiguix.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;;
;;; Packages of Intel's AI stack, which Guix keeps in (gnu packages
;;; oneapi).
;;;
;;; Code:

(define-module (aiguix packages oneapi)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system copy)
  #:use-module (guix build-system meson)
  #:use-module (guix build-system pyproject)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (gnu packages)
  #:use-module (gnu packages algebra)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages bison)
  #:use-module (gnu packages check)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages compiler-tools)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cpp)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages dns)
  #:use-module (gnu packages graphviz)
  #:use-module (gnu packages image-processing)
  #:use-module (gnu packages libedit)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages logging)
  #:use-module ((gnu packages machine-learning)
                #:select (python-pytorch
                          python-scikit-learn
                          python-torchvision
                          sentencepiece
                          tensorflow-lite))
  #:use-module (gnu packages mpi)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages oneapi)
  #:use-module (gnu packages opencl)
  #:use-module (gnu packages pciutils)
  #:use-module (gnu packages pcre)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages pretty-print)
  #:use-module (gnu packages profiling)
  #:use-module (gnu packages protobuf)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-science)
  #:use-module ((gnu packages python-web) #:select (python-requests))
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages regex)
  #:use-module (gnu packages serialization)
  #:use-module (gnu packages stb)
  #:use-module (gnu packages tls)
  #:use-module ((gnu packages version-control) #:select (git-minimal))
  #:use-module (gnu packages video)
  #:use-module (gnu packages vulkan)
  #:use-module (gnu packages web)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages xorg)
  #:use-module (aiguix packages audio)
  #:use-module (aiguix packages cpp)
  #:use-module (aiguix packages flashing-tools)
  #:use-module (aiguix packages machine-learning)
  #:use-module (aiguix packages monitoring)
  #:use-module (aiguix packages python-web)
  #:use-module (aiguix packages rpc)
  #:use-module (aiguix packages version-control)
  #:use-module (aiguix packages vulkan)
  #:use-module (aiguix packages web))

;; The loader of Guix finds drivers such as intel-compute-runtime only
;; through LD_LIBRARY_PATH.  This variant finds them in the profile.
(define-public level-zero/driver-path
  (hidden-package
   (package
     (inherit level-zero)
     (source
      (origin
        (inherit (package-source level-zero))
        (patches
         (list (local-file "patches/level-zero-guix-driver-path.patch")))))
     (native-search-paths
      (list (search-path-specification
             (variable "GUIX_LEVEL_ZERO_DRIVER_PATH")
             (files '("lib"))))))))

(define-public level-zero-npu-extensions
  ;; There are no releases; this is the commit that the NPU plugin of
  ;; OpenVINO 2026.4.1 uses.
  (let ((commit "b11dc98b48f9f0dbb8c3b44f73b42f295a32097f")
        (revision "0"))
    (package
      (name "level-zero-npu-extensions")
      (version (git-version "0.0.0" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/intel/level-zero-npu-extensions")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "05wj4240z0yrbsxbvsz2skbch2ajrxpgjvvqkia59iz2aqgyqn6k"))))
      (build-system copy-build-system)
      (arguments
       (list
        ;; The headers include "ze_api.h", so they go next to it.
        #:install-plan
        #~'(("." "include/level_zero"
             #:include-regexp ("\\.h$")))))
      (home-page "https://github.com/intel/level-zero-npu-extensions")
      (synopsis "Level Zero extension headers for Intel NPUs")
      (description
       "This package provides the headers of the Level Zero extensions for the
neural processing unit (NPU) of Intel CPUs, such as the graph extension used
to load and run compiled models.  The NPU driver, the NPU plugin of OpenVINO
and the NPU compiler are built against them.")
      (license license:expat))))

(define-public openvino
  (package
    (name "openvino")
    (version "2026.4.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/openvinotoolkit/openvino")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0cfgzi6wi04bsnxzzpzs8jhbix7rjqjaahn415vzr2kxzc6inr72"))
       (modules '((guix build utils)))
       (snippet
        #~(begin
            (define (add-source source directory unused)
              ;; Copy SOURCE to DIRECTORY, where upstream expects a Git
              ;; submodule, and remove its UNUSED third-party directories.
              (copy-recursively source directory)
              (for-each make-file-writable
                        (find-files directory #:directories? #t))
              (with-directory-excursion (string-append directory
                                                       "/third_party")
                (for-each delete-file-recursively unused)))

            ;; RapidJSON is taken from Guix.
            (delete-file-recursively
             "src/plugins/intel_gpu/thirdparty/rapidjson")

            ;; The CPU plugin needs OpenVINO's fork of oneDNN, which carries
            ;; OpenVINO-specific patches.  It is built for x86_64 without GPU
            ;; runtime and without tests.
            (add-source
             #$(origin
                 (method git-fetch)
                 (uri (git-reference
                       (url "https://github.com/openvinotoolkit/oneDNN")
                       (commit "1289c3b65dd6a119a5ed12a816517d9c3a21d81b")))
                 (file-name "openvino-onednn-cpu-checkout")
                 (sha256
                  (base32
                   "0gs6ijjcb4nhp84xjzj00aj3ccca3ak153bkxqp0m50rpw8zx3i3")))
             "src/plugins/intel_cpu/thirdparty/onednn"
             '("gtest" "level_zero" "mdapi" "ngen" "opencl"
               "xbyak_aarch64" "xbyak_riscv"))

            ;; The GPU plugin builds oneDNN as an ExternalProject, without
            ;; CPU runtime and without tests.  The source of the onednn
            ;; package cannot be used: its snippet empties generated files
            ;; that the package regenerates with castxml.
            (add-source
             #$(origin
                 (method git-fetch)
                 (uri (git-reference
                       (url "https://github.com/oneapi-src/oneDNN")
                       (commit "a3d459721b72c3a9d2685b46c03dafee7af0f25c")))
                 (file-name "openvino-onednn-gpu-checkout")
                 (sha256
                  (base32
                   "1x2qlcwrvwrx2r64093qdhhma9vcbzrd3kx0izlmyhk6wpbrs1bw")))
             "src/plugins/intel_gpu/thirdparty/onednn_gpu"
             '("gtest" "xbyak_aarch64" "xbyak_riscv"))

            ;; OpenVINO's fork of MLAS from ONNX Runtime, which has no
            ;; releases of its own.
            (copy-recursively
             #$(origin
                 (method git-fetch)
                 (uri (git-reference
                       (url "https://github.com/openvinotoolkit/mlas")
                       (commit "d1bc25ec4660cddd87804fcf03b2411b5dfb2e94")))
                 (file-name "openvino-mlas-checkout")
                 (sha256
                  (base32
                   "0579j55y31frqfmc527cbflqadpfc2jbs4hqypq4kh3p854r1i8b")))
             "src/plugins/intel_cpu/thirdparty/mlas")))))
    (build-system cmake-build-system)
    (outputs '("out" "developer"))
    (arguments
     (list
      ;; As recommended by upstream; debugging information would be huge.
      #:build-type "Release"
      ;; The unit tests need OpenVINO's fork of googletest, and the frontend
      ;; tests need models generated with TensorFlow and PaddlePaddle at
      ;; build time.  python-openvino checks that the libraries load.
      #:tests? #f
      #:configure-flags
      #~(list "-DCPACK_GENERATOR=CONDA-FORGE" ;GNU installation layout
              ;; Setting CI_BUILD_NUMBER (see 'set-version') would otherwise
              ;; turn warnings into errors, as in upstream's CI.
              "-DCMAKE_COMPILE_WARNING_AS_ERROR=OFF"
              "-DENABLE_SYSTEM_TBB=ON"
              "-DENABLE_SYSTEM_PUGIXML=ON"
              "-DENABLE_SYSTEM_PROTOBUF=ON"
              "-DENABLE_SYSTEM_FLATBUFFERS=ON"
              "-DENABLE_SYSTEM_SNAPPY=ON"
              "-DENABLE_SYSTEM_OPENCL=ON"
              "-DENABLE_SYSTEM_LEVEL_ZERO=ON"
              ;; The oneDNN fork of the CPU plugin needs OpenCL headers even
              ;; without GPU runtime; use those from Guix.
              (string-append "-DDNNL_OCL_INCLUDE_DIR="
                             #$(this-package-input "opencl-headers")
                             "/include")
              "-DTHREADING=TBB"
              ;; onetbb is built without hwloc, so there is no TBBBind
              ;; library; do not download a prebuilt static one.
              "-DENABLE_TBBBIND_2_5=OFF"
              ;; The ONNX frontend needs onnx >= 1.22, which Guix lacks.
              "-DENABLE_OV_ONNX_FRONTEND=OFF"
              ;; The JAX frontend is only installed with the Python
              ;; bindings, but openvino.pc would list it anyway.
              "-DENABLE_OV_JAX_FRONTEND=OFF"
              ;; This would download a prebuilt NPU compiler; the NPU driver
              ;; and plugin load the one of npu-compiler instead.
              "-DENABLE_INTEL_NPU_COMPILER=OFF"
              ;; The internal NPU tools, such as compile_tool, need the
              ;; bundled gflags.
              "-DENABLE_INTEL_NPU_INTERNAL=OFF"
              ;; Windows-only telemetry client of the AUTO plugin.
              "-DENABLE_IPF_CLIENT_API=OFF"
              ;; Example plugin for plugin developers.
              "-DENABLE_TEMPLATE=OFF"
              "-DENABLE_NCC_STYLE=OFF"
              "-DENABLE_CLANG_FORMAT=OFF"
              "-DENABLE_SAMPLES=OFF"
              "-DENABLE_TESTS=OFF"
              ;; The Python bindings are built by python-openvino.
              "-DENABLE_PYTHON=OFF"
              "-DENABLE_WHEEL=OFF"
              ;; The Node.js bindings download their headers at build time.
              "-DENABLE_JS=OFF")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'use-system-liburing
            (lambda _
              ;; Link against liburing from Guix instead of building the
              ;; bundled copy, and do not export or install it.
              (substitute* "thirdparty/dependencies.cmake"
                (("add_subdirectory\\(thirdparty/liburing [A-Z_]+\\)")
                 (string-append
                  "pkg_search_module(liburing REQUIRED IMPORTED_TARGET"
                  " GLOBAL liburing)\n"
                  "    add_library(openvino::liburing ALIAS"
                  " PkgConfig::liburing)"))
                ((".*TARGET openvino_liburing PROPERTY EXPORT_NAME.*") "")
                ((".*export_targets\\(TARGET openvino::liburing.*") "")
                ((".*INSTALL_INCLUDE_DIRECTORIES .*openvino::liburing.*") "")
                ((".*ov_install_static_lib\\(openvino_liburing.*") ""))))
          (add-after 'unpack 'use-system-npu-extensions
            (lambda* (#:key inputs #:allow-other-keys)
              (substitute* "src/plugins/intel_npu/thirdparty/CMakeLists.txt"
                (("\\$\\{CMAKE_CURRENT_SOURCE_DIR\\}/level-zero-ext/")
                 (dirname
                  (search-input-file inputs
                                     "include/level_zero/ze_graph_ext.h"))))
              ;; This target only exists with the bundled Level Zero.
              (substitute*
                  "src/plugins/intel_npu/src/utils/src/vm/CMakeLists.txt"
                (("^add_dependencies\\(.* prepare_ze_headers\\)" all)
                 (string-append "if(TARGET prepare_ze_headers)\n    " all
                                "\nendif()")))))
          (add-after 'unpack 'find-level-zero
            (lambda* (#:key inputs #:allow-other-keys)
              ;; The NPU plugin opens the Level Zero loader by name.
              (substitute* "src/common/zero_loader/src/zero.api.cpp"
                (("ov::util::make_plugin_library_name\\(\\{\\}, baseName\\);")
                 (string-append
                  "std::filesystem::path(\""
                  (search-input-file inputs "lib/libze_loader.so.1")
                  "\");"))
                (("libpath \\+= LIB_ZE_LOADER_SUFFIX;") ""))))
          (add-after 'unpack 'accept-protobuf-6
            (lambda _
              ;; OpenVINO accepts protobuf >= 5.26 and < 7, but the CMake
              ;; package file of protobuf 6 rejects any request whose major
              ;; version is not 6, so ask for 6 explicitly.
              (substitute* "thirdparty/dependencies.cmake"
                (("find_package\\(Protobuf 5\\.26\\.0 QUIET CONFIG\\)")
                 "find_package(Protobuf 6 QUIET CONFIG)"))))
          (add-after 'unpack 'keep-install-rpath
            (lambda _
              ;; Like Homebrew, Guix relies on RUNPATHs to find
              ;; libopenvino.so from the frontends and plugins.
              (with-directory-excursion "cmake/developer_package/packaging"
                (substitute* "common-libraries.cmake"
                  (("if\\(CPACK_GENERATOR STREQUAL \"BREW\"\\)")
                   "if(TRUE)")))))
          (add-before 'configure 'set-version
            (lambda _
              ;; Without Git, the build number would be guessed.
              (setenv "CI_BUILD_NUMBER"
                      (string-append #$version "-000-guix"))))
          (add-after 'install 'fix-pkg-config-file
            (lambda _
              ;; pugixml is only used by libopenvino.so itself; list it for
              ;; static linking only.
              (substitute* (string-append #$output
                                          "/lib/pkgconfig/openvino.pc")
                ((" -lpugixml") "")
                (("^Libs\\.private: ") "Libs.private: -lpugixml "))))
          (add-after 'install 'install-developer-package
            (lambda _
              ;; Internal headers, static helper libraries and CMake scripts
              ;; needed to build extensions such as the Python bindings.
              (invoke "cmake" "--install" "."
                      "--component" "developer_package"
                      "--prefix" #$output:developer))))))
    (native-inputs (list pkg-config python-minimal))
    ;; The public header openvino/core/parallel.hpp includes TBB headers, and
    ;; OpenVINOConfig.cmake and openvino.pc require TBB.
    (propagated-inputs (list onetbb))
    (inputs (list abseil-cpp
                  flatbuffers
                  ittapi
                  level-zero/driver-path
                  level-zero-npu-extensions
                  libva
                  liburing
                  nlohmann-json
                  opencl-clhpp
                  opencl-headers
                  opencl-icd-loader
                  protobuf-6
                  pugixml
                  rapidjson
                  snappy
                  xbyak))
    ;; Let the Level Zero and OpenCL loaders find the drivers, such as
    ;; intel-compute-runtime, when both are in the same profile.
    (native-search-paths
     (append (package-native-search-paths level-zero/driver-path)
             (package-native-search-paths opencl-icd-loader)))
    (supported-systems '("x86_64-linux"))
    (home-page "https://docs.openvino.ai/")
    (synopsis "Toolkit for optimizing and deploying AI inference")
    (description
     "OpenVINO is a toolkit for optimizing and deploying deep learning models.
It converts models from frameworks such as TensorFlow, TensorFlow Lite and
PyTorch into its own intermediate representation and runs them on CPUs,
Intel GPUs and the NPU of Intel CPUs.  On the NPU, it needs
@code{linux-npu-driver} and @code{npu-compiler} in the same profile.")
    ;; OpenVINO and oneDNN are under the Apache 2.0 license, MLAS under Expat.
    (license (list license:asl2.0 license:expat))))

(define-public intel-compute-runtime
  (package
    (name "intel-compute-runtime")
    (version "26.40.40196.8")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/intel/compute-runtime")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "00255v5gnsm4jxncxxzh94iwb93jkljly9l9f94qw7h74imp8g2z"))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:tests? #f
      #:configure-flags
      #~(let ((igc #$(this-package-input "intel-graphics-compiler")))
          (list
           ;; #:tests? #f does not keep the build from compiling the unit
           ;; tests, which takes long and much disk space.
           "-DNEO_SKIP_UNIT_TESTS=1"
           ;; The NEO_* environment variables, such as
           ;; NEO_OverridePreemptionSurfaceSizeInMb, work in the release
           ;; build.
           "-DRELEASE_WITH_REGKEYS=TRUE"
           ;; Only the DRM driver model of Linux, not the one of WSL.
           "-DDISABLE_WDDM_LINUX=TRUE"
           ;; ocloc loads libigdfcl.so.2 from there while it compiles the
           ;; built-in kernels during the build.
           (string-append "-DIGC_DIR=" igc)
           ;; The default is /etc/OpenCL/vendors; opencl-icd-loader finds
           ;; the file in the profile through OCL_ICD_VENDORS.
           (string-append "-DOCL_ICD_VENDORDIR="
                          #$output "/etc/OpenCL/vendors")
           "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON"
           ;; ocloc needs libocloc.so, which CMake installs without
           ;; setting its RPATH, and the drivers load libigdfcl.so.2 and
           ;; libigc.so with dlopen by their bare names.
           (string-append "-DCMAKE_INSTALL_RPATH="
                          #$output "/lib;"
                          igc "/lib")))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'allow-rpath
            (lambda _
              ;; CMakeLists.txt force-sets CMAKE_SKIP_RPATH to YES,
              ;; overriding every RPATH flag above -- confirmed by
              ;; rebuilds showing only glibc/gcc's implicit defaults
              ;; in RUNPATH. Upstream relies on system ldconfig
              ;; instead, which doesn't apply to Guix's store layout.
              (substitute* "CMakeLists.txt"
                (("set\\(CMAKE_SKIP_RPATH YES CACHE BOOL \"\" FORCE\\)")
                 "set(CMAKE_SKIP_RPATH NO CACHE BOOL \"\" FORCE)")))))))
    (inputs (list gmmlib intel-graphics-compiler libva zlib))
    (native-inputs (list level-zero pkg-config))
    (home-page "https://github.com/intel/compute-runtime")
    (synopsis
     "Intel Graphics Compute Runtime for oneAPI Level Zero and OpenCL")
    (description
     "NEO (intel-compute-runtime) implements the OpenCL 3.0
and oneAPI Level Zero APIs for Intel GPUs, from integrated graphics
(Tiger Lake through Panther Lake) through discrete cards (DG1, Arc
Alchemist, Arc Battlemage).  It loads the Intel Graphics Compiler at
runtime to JIT-compile OpenCL C/SPIR-V kernels submitted by
applications into Intel GPU machine code.")
    (license license:expat)))

(define-public intel-graphics-compiler
  (package
    (name "intel-graphics-compiler")
    (version "2.42.6")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/intel/intel-graphics-compiler")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "08j9nqh1v30x8iy69rk0limpj1xjl4h32p8fs8fix0cqazgrn7s0"))
       (modules '((guix build utils)))
       (snippet
        #~(begin
            ;; IRBuilderGeneratorCodeGen.cmake compiles some sources with
            ;; clang for x86_64-pc-windows, with -nostdinc and the copy of
            ;; the clang headers that IGC ships.  CPLUS_INCLUDE_PATH still
            ;; reaches clang, so their stdint.h would include the one of
            ;; glibc, where int64_t is long, which has 32 bits on Windows.
            ;; Without a hosted C library it does not.
            (substitute* "IGC/cmake/IRBuilderGeneratorCodeGen.cmake"
              (("-target x86_64-pc-windows" all)
               (string-append all " -ffreestanding")))
            ;; LLVMModule->dump() only exists when LLVM is built with
            ;; assertions, which the LLVM of Guix is not.
            (substitute* "IGC/AdaptorOCL/dllInterfaceCompute.cpp"
              (("LLVMModule->dump\\(\\);") ";"))))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:tests? #f
      #:configure-flags
      #~(let ((clang #$(this-package-native-input "clang"))
              (lld #$(this-package-native-input "lld"))
              (llvm #$(this-package-native-input "llvm"))
              (opencl-clang #$(this-package-native-input "opencl-clang"))
              (spirv-llvm-translator
               #$(this-package-native-input "spirv-llvm-translator"))
              (zlib #$(this-package-input "zlib")))
          (list "-DIGC_OPTION__LLVM_MODE=Prebuilds"
                (string-append "-DIGC_OPTION__LLVM_PREFERRED_VERSION="
                               #$(package-version llvm-22))
                (string-append "-DCMAKE_INSTALL_PREFIX=" #$output)
                ;; libigc and libigdfcl link against LLVM, zlib, opencl-clang
                ;; and the translator; CMake does not add them to the RPATH
                ;; by itself.
                "-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON"
                (string-append "-DCMAKE_INSTALL_RPATH="
                               llvm "/lib;"
                               zlib "/lib;"
                               opencl-clang "/lib;"
                               spirv-llvm-translator "/lib")
                (string-append "-DCMAKE_PREFIX_PATH="
                               llvm ";"
                               spirv-llvm-translator ";" opencl-clang)
                ;; The defaults point to prebuilt LLD for Windows.
                (string-append "-DIGC_OPTION__LLDELF_LIB_DIR=" lld)
                (string-append "-DIGC_OPTION__LLD_BIN_DIR=" lld)
                (string-append "-DIGC_OPTION__LLDELF_H_DIR=" lld)
                ;; The opencl-c.h of clang; without it, the build searches
                ;; the directory of the clang binary for the file.
                (string-append "-DIGC_OPTION__OPENCL_HEADER_PATH="
                               clang "/lib/clang/"
                               #$(version-major (package-version llvm-22))
                               "/include/opencl-c.h")
                "-DCMAKE_INSTALL_LIBDIR=lib"))
      #:phases
      #~(modify-phases %standard-phases
          ;; IGC builds vc-intrinsics, SPIRV-Tools and SPIRV-Headers with
          ;; itself and looks for them next to its source directory.
          (add-after 'unpack 'add-vc-intrinsics
            (lambda _
              (copy-recursively #$(package-source vc-intrinsics)
                                "../vc-intrinsics")))
          (add-after 'unpack 'add-spirv-tools
            (lambda _
              (copy-recursively #$(package-source spirv-tools-for-igc)
                                "../SPIRV-Tools")))
          (add-after 'unpack 'add-spirv-headers
            (lambda _
              (copy-recursively #$(package-source spirv-headers-1.4.357.0)
                                "../SPIRV-Headers")))
          ;; As in Guix, build in a subdirectory of the source.
          (replace 'configure
            (lambda* (#:key configure-flags #:allow-other-keys)
              (mkdir-p "build")
              (chdir "build")
              (apply invoke "cmake" ".." configure-flags))))))
    (inputs (list libedit ncurses zlib zstd))
    (native-inputs
     (list bison
           clang-22
           flex
           git-minimal
           lld-22
           llvm-22
           opencl-clang-22
           pkg-config
           python
           python-mako
           python-pyyaml
           spirv-headers-1.4.357.0
           spirv-llvm-translator-22
           spirv-tools-for-igc))
    (home-page "https://github.com/intel/intel-graphics-compiler")
    (synopsis "Intel Graphics Compiler for OpenCL")
    (description
     "The Intel Graphics Compiler (IGC) is an LLVM-based compiler for OpenCL
targeting Intel graphics hardware.")
    (license license:expat)))

(define-public linux-npu-driver
  (package
    (name "linux-npu-driver")
    (version "1.38.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/intel/linux-npu-driver")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0qf1jh1p2xvxm1zsr0ww8m3svdhg7amdfvh2j3idrh7n6bknnl23"))
       (modules '((guix build utils)))
       (snippet
        ;; Remove the nonfree NPU firmware and the bundled Perfetto SDK;
        ;; the SDK comes from the source of perfetto.
        #~(for-each delete-file-recursively
                    '("firmware/bin" "third_party/perfetto")))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list "-DENABLE_TOOLS_BUILD=ON"
              ;; Tracing with Perfetto, turned on at run time with
              ;; ZE_INTEL_NPU_LOGPERFETTO.
              "-DENABLE_NPU_PERFETTO_BUILD=ON"
              ;; The validation tests need a real NPU.
              "-DENABLE_VALIDATION_BUILD=OFF")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'unpack-npu-compiler-elf
            (lambda _
              ;; The ELF library has no install rules and is meant to be
              ;; built as part of the driver, which also provides the
              ;; firmware API headers it needs.
              (copy-recursively
               #$(this-package-native-input "npu-compiler-elf-checkout")
               "third_party/npu_compiler_elf")))
          (add-after 'unpack 'use-system-npu-extensions
            (lambda* (#:key inputs #:allow-other-keys)
              (substitute*
                  "third_party/cmake/level-zero-npu-extensions.cmake"
                (("\\$\\{CMAKE_CURRENT_SOURCE_DIR\\}/[a-z-]+")
                 (dirname
                  (search-input-file inputs
                                     "include/level_zero/ze_graph_ext.h"))))))
          (add-after 'unpack 'use-perfetto-sdk
            (lambda _
              ;; The driver builds the SDK, two files, into itself.
              (substitute* "third_party/cmake/perfetto.cmake"
                (("\\$\\{CMAKE_CURRENT_SOURCE_DIR\\}/perfetto")
                 #$(package-source perfetto)))))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              ;; The unit tests use mocks instead of a real NPU.  Skip the
              ;; suites that need a model or a compiled blob, which the
              ;; validation tests would download.
              (when tests?
                (invoke "bin/npu_shared_tests")
                (invoke "bin/ze_intel_npu_tests"
                        (string-append "--gtest_filter=-"
                                       "CommandListGraphApiTest.*:"
                                       "CompilerInDriver.*:"
                                       "GraphExecution.*:"
                                       "GraphNativeTest.*"))))))))
    (native-inputs
     (list googletest
           (origin
             (method git-fetch)
             (uri (git-reference
                   (url "https://github.com/openvinotoolkit/npu_compiler_elf")
                   (commit "d325f45f2cb405b5fa2ff17a30de9469f1641b73")))
             (file-name "npu-compiler-elf-checkout")
             (sha256
              (base32
               "0xbaxxn45q662khma8kcs1s0hnl9l58ylcav30a16mvjjjkyx4cf")))
           pkg-config))
    ;; The driver implements the Level Zero 1.32 interface.
    (inputs (list level-zero-1.32.0 level-zero-npu-extensions yaml-cpp))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/intel/linux-npu-driver")
    (synopsis "User-space driver for the NPU of Intel CPUs")
    (description
     "This package provides the Level Zero driver for the neural processing
unit (NPU) of Intel Core Ultra CPUs, which lets programs such as OpenVINO run
inference on it through the @code{intel_vpu} kernel driver.  It also provides
@command{intel-npu-smi}, which shows the use and frequency of the NPU.  The
NPU firmware is not part of this package.  To compile models, the driver
needs the NPU compiler, a separate package, installed in the same profile;
without it, the driver can only run models compiled beforehand.  For users
to access the NPU, add @code{npu-service-type} from @code{(aiguix services
npu)} to the @code{operating-system} configuration.")
    (license license:expat)))

(define-public npu-compiler
  (let ((commit "37a2ec119255903a3a6066dbe02c91b563dfc44c")
        (revision "0"))
    (package
      (name "npu-compiler")
      ;; Upstream marks this commit as the content for OpenVINO 2026.4.1.
      (version (git-version "2026.4.1" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/openvinotoolkit/npu_compiler")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "0kq7nb9g1ggxk2blgmgbxa4m5qbpf4d9xhslp2fvjzg58wd23qbx"))
         (modules '((guix build utils)))
         (snippet
          ;; git-fetch gets only the Git LFS pointers of the prebuilt SHAVE
          ;; kernels, not the kernels.  Remove them, but keep the linker
          ;; scripts.  The kernels run on the vector cores of the NPU, and
          ;; neither their source code nor the toolchain that builds them
          ;; is public.
          #~(for-each delete-file
                      (find-files "sw_runtime_kernels"
                                  (lambda (file stat)
                                    (and (string-contains file "/prebuild/")
                                         (not (string-suffix? ".ld"
                                                              file)))))))))
      (build-system cmake-build-system)
      (arguments
       (list
        #:build-type "Release"
        #:tests? #f
        #:configure-flags
        #~(let ((developer (search-input-directory %build-inputs
                                                   "developer_package")))
            (list (string-append "-DOpenVINODeveloperPackage_DIR="
                                 developer "/cmake")
                  ;; Do not keep a reference to the "developer" output.
                  (string-append "-DCMAKE_CXX_FLAGS=-ffile-prefix-map="
                                 developer "=developer_package")
                  ;; Build the libraries that the NPU driver loads.
                  "-DBUILD_COMPILER_FOR_DRIVER=ON"
                  "-DENABLE_NPU_EXECUTION_ENGINE=OFF"
                  "-DENABLE_NPU_LSP_SERVER=OFF"
                  "-DENABLE_PRIVATE_TESTS=OFF"
                  "-DENABLE_CPPLINT=OFF"
                  "-DENABLE_LTO=OFF"
                  "-DENABLE_FASTER_BUILD=OFF"))
        #:phases
        #~(modify-phases %standard-phases
            (add-after 'unpack 'unpack-submodules
              (lambda _
                (for-each
                 (lambda (source directory)
                   (copy-recursively source directory)
                   (for-each make-file-writable
                             (find-files directory #:directories? #t)))
                 (list #$(this-package-native-input "npu-compiler-llvm")
                       #$(this-package-native-input "npu-compiler-elf")
                       #$(this-package-native-input "npu-nn-cost-model"))
                 '("thirdparty/llvm-project"
                   "thirdparty/elf"
                   "thirdparty/vpucostmodel"))))
            (add-after 'unpack 'use-system-flatbuffers
              (lambda* (#:key inputs #:allow-other-keys)
                ;; Provide the targets that a build inside the OpenVINO tree
                ;; would provide, before the cost model looks for them.
                (let ((flatc (search-input-file inputs "bin/flatc")))
                  (substitute* "thirdparty/CMakeLists.txt"
                    (("^set\\(VPUNN_BUILD_SHARED_LIB " all)
                     (string-append
                      "find_package(nlohmann_json CONFIG REQUIRED)\n"
                      "find_package(flatbuffers CONFIG REQUIRED)\n"
                      "add_executable(flatc IMPORTED GLOBAL)\n"
                      "set_target_properties(flatc PROPERTIES"
                      " IMPORTED_LOCATION \"" flatc "\")\n"
                      "add_library(flatbuffers INTERFACE)\n"
                      "target_link_libraries(flatbuffers INTERFACE"
                      " flatbuffers::flatbuffers)\n"
                      "set(flatbuffers_TARGET flatbuffers PARENT_SCOPE)\n"
                      "set(flatc_TARGET flatc PARENT_SCOPE)\n"
                      "set(flatc_COMMAND \"" flatc "\" PARENT_SCOPE)\n"
                      all))))))
            (add-after 'unpack 'find-openvino-dependencies
              (lambda _
                ;; The developer package of openvino refers to these targets
                ;; without looking for them.
                (substitute* "CMakeLists.txt"
                  (("^find_package\\(OpenVINODeveloperPackage" all)
                   (string-append "find_package(ittapi CONFIG REQUIRED)\n"
                                  all)))))
            (add-after 'unpack 'set-commit
              (lambda _
                ;; There is no Git repository to ask.
                (substitute* "cmake/compiler_commit_hash.cmake"
                  (("git rev-parse HEAD")
                   (string-append "echo " #$commit)))))
            (add-after 'unpack 'skip-driver-compiler-tests
              (lambda _
                ;; These tests need the googletest fork of OpenVINO, which
                ;; its developer package does not provide.
                (substitute* "src/vpux_driver_compiler/CMakeLists.txt"
                  (("^add_subdirectory\\(test\\)") ""))))
            (add-after 'unpack 'install-to-prefix
              (lambda _
                ;; Install the libraries to lib/ instead of cid/lib/.
                (substitute* "src/CMakeLists.txt"
                  (("set\\(INSTALL_DESTINATION cid\\)")
                   "set(INSTALL_DESTINATION .)"))))
            (add-after 'unpack 'find-compiler-library
              (lambda _
                ;; The loader looks for the compiler next to libopenvino,
                ;; which is a separate package; give it the full file name.
                (substitute* (string-append "src/vpux_driver_compiler/src/"
                                            "vpux_compiler_l0/"
                                            "vcl_compiler_loader.cpp")
                  (("ov::util::make_plugin_library_name\\([^;]*\\)\\)")
                   (string-append "std::string(\"" #$output "/lib/"
                                  "libopenvino_intel_npu_compiler.so\"))")))))
            (replace 'build
              (lambda* (#:key parallel-build? #:allow-other-keys)
                (invoke "cmake" "--build" "."
                        "--parallel" (if parallel-build?
                                         (number->string
                                          (parallel-job-count))
                                         "1")
                        "--target" "openvino_intel_npu_compiler"
                        "openvino_intel_npu_compiler_loader")))
            (replace 'install
              (lambda _
                (invoke "cmake" "--install" "." "--component" "CiD"
                        "--prefix" #$output)
                (with-directory-excursion #$output
                  ;; The sources and static library of the ELF loader, for
                  ;; drivers that build it in, and a copy of the header.
                  (delete-file-recursively "cid")
                  (delete-file "npu_driver_compiler.h")
                  (let ((doc (string-append "share/doc/" #$name "-"
                                            #$version)))
                    (mkdir-p doc)
                    (for-each (lambda (file)
                                (rename-file file
                                             (string-append doc "/" file)))
                              '("CHANGES.txt" "README.md"
                                "build_manifest.json")))
                  ;; The NPU plugin of OpenVINO looks for the loader next
                  ;; to itself, to compile models without the driver, for
                  ;; example for an NPU that is not present.
                  (let ((plugins (string-append
                                  "lib/openvino-"
                                  #$(package-version openvino))))
                    (mkdir-p plugins)
                    (symlink
                     "../libopenvino_intel_npu_compiler_loader.so"
                     (string-append
                      plugins
                      "/libopenvino_intel_npu_compiler_loader.so")))))))))
      (native-inputs
       (list git-minimal
             (list openvino "developer")
             (origin
               (method git-fetch)
               (uri (git-reference
                     (url
                      "https://github.com/intel-staging/npu-compiler-llvm")
                     (commit "980c1ca33aad7bda278934cbb1e03268b92cf64e")))
               (file-name "npu-compiler-llvm")
               (sha256
                (base32
                 "05kkd6gpscxv1rf0fivyx0iszhcbs4b83g4xyxdr4cgknv6k5jkw")))
             (origin
               (method git-fetch)
               (uri (git-reference
                     (url
                      "https://github.com/openvinotoolkit/npu_compiler_elf")
                     (commit "edbd3b0dbb6f51f4f6c18aba3b26d4c20b1a5964")))
               (file-name "npu-compiler-elf")
               (sha256
                (base32
                 "1i2gzb5rp9k5qqs651n1nk64qa8h1d3kylb0nqahid5iw5ryx0fq")))
             (origin
               (method git-fetch)
               (uri (git-reference
                     (url "https://github.com/intel/npu-nn-cost-model")
                     (commit "6b89f4285cf17c9bcc763e5b320c996612cf7a87")))
               (file-name "npu-nn-cost-model")
               (sha256
                (base32
                 "01p6m45hcn5sp4352my3f07idi9hz00wmxb1klfh02fa4mkwhjgm")))
             python-minimal))
      (inputs
       (list flatbuffers ittapi nlohmann-json openvino pugixml zlib))
      (supported-systems '("x86_64-linux"))
      (home-page "https://github.com/openvinotoolkit/npu_compiler")
      (synopsis "Model compiler for the NPU of Intel CPUs")
      (description
       "This package provides the compiler that the NPU driver
@code{linux-npu-driver} and the NPU plugin of OpenVINO use to compile
OpenVINO models for the neural processing unit (NPU) of Intel Core Ultra
CPUs.  The plugin uses it to compile models for an NPU that is not present,
given with the property @code{NPU_PLATFORM}.  It is built on MLIR and
includes the VPUNN cost model.  The prebuilt SHAVE kernels, which run
operations such as Softmax on the vector cores of the NPU, are not part of
this package: their source code is not public.  Without them, the compiler
can only compile models whose operations run on the matrix units of the NPU.
Activations such as ReLU and conversions between data types also need the
kernels, so most models fail to compile, among them every model with
@code{f32} inputs or outputs; a model of matrix multiplications in
@code{f16} compiles.")
      (license license:asl2.0))))

;; Needed by Intel Graphics Compiler, which requires this exact major version.
(define-public opencl-clang-22
  (package
    (name "opencl-clang")
    (version "22.1.4")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/intel/opencl-clang")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "19416b7g4wbjfmibzgr33b1sd7yh5h1zn999064jbkfgkwp4gpd5"))
       ;; LLVM and Clang lie in separate prefixes, as in opencl-clang of
       ;; Guix.
       (patches (search-patches
                 "opencl-clang-separate-llvm-clang-prefix.patch"))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:configure-flags
      #~(let ((llvm #$(this-package-input "llvm"))
              (clang #$(this-package-input "clang")))
          (list
           ;; The version of LLVM that the build looks for.
           (string-append "-DPREFERRED_LLVM_VERSION="
                          #$(package-version llvm-22))
           ;; LLVM and Clang of Guix, instead of building them in-tree.
           (string-append "-DLLVM_DIR=" llvm "/lib/cmake/llvm")
           (string-append "-DClang_DIR=" clang "/lib/cmake/clang")
           ;; The SPIR-V translator is a package of its own.
           "-DLLVMSPIRV_INCLUDED_IN_LLVM=OFF"
           (string-append "-DSPIRV_TRANSLATOR_DIR="
                          #$(this-package-input "spirv-llvm-translator"))
           ;; Set up the tests, with lit of Guix: an in-tree build of LLVM
           ;; would provide it.
           "-DLLVM_INCLUDE_TESTS=ON"
           (string-append "-DLLVM_EXTERNAL_LIT="
                          #$(this-package-native-input "python-lit")
                          "/bin/lit")
           ;; The tests look for clang next to the tools of LLVM; here it
           ;; lies in a separate prefix.
           (string-append "-DCLANG_TOOLS_DIR=" clang "/bin")))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'adjust-tests
            (lambda _
              ;; The tests look for occ-cli next to LLVM, as in an in-tree
              ;; build; with an external LLVM it lies in the build directory.
              (substitute* "tests/lit.site.cfg.py.in"
                (((string-append "opencl_clang_tools_dir = "
                                 "lit_config\\.substitute\\(path\\("
                                 "r\"@LLVM_TOOLS_DIR@"))
                 (string-append "opencl_clang_tools_dir = "
                                "lit_config.substitute(path("
                                "r\"@CMAKE_CURRENT_BINARY_DIR@/occ-cli")))
              ;; This test uses -cl-std=CL3.1, which Clang 22 rejects:
              ;; opencl-clang carries the patches for it in patches/clang
              ;; and applies them only when it builds Clang itself.
              (substitute* "tests/lit.cfg.py"
                (("\"Conformance\"\\]")
                 "\"Conformance\", \"cl-ext-option.cl\"]"))))
          ;; The tests are a target of the build, not registered with CTest.
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "cmake" "--build" "."
                        "--target" "check-opencl-clang")))))))
    (native-inputs (list pkg-config python-lit))
    (inputs (list llvm-22 clang-22 spirv-llvm-translator-22))
    (home-page "https://github.com/intel/opencl-clang")
    (synopsis "OpenCL C compiler library for Intel GPUs, for LLVM 22")
    (description
     "opencl-clang is a library that compiles OpenCL C to LLVM IR and SPIR-V
with Clang.  Intel Graphics Compiler loads it to compile the OpenCL C
kernels of applications.  This variant is built against LLVM 22.")
    (license license:asl2.0)))   ;with LLVM exceptions

(define-public openvino-genai
  (package
    (name "openvino-genai")
    ;; Keep in sync with the version of openvino.
    (version "2026.4.1.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/openvinotoolkit/openvino.genai")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1dzxv2c1lnsrsh0rpb2ab8dx1i0s8pazn7wpv3dgh33p35qg61rn"))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:build-type "Release"
      ;; The test suite needs models downloaded from the network; 'check'
      ;; only checks that the Python module loads.
      #:configure-flags
      ;; GGUF support cannot be disabled: some sources include the GGUF
      ;; headers even with ENABLE_GGUF=OFF.  The GGUF parser is built from
      ;; this fork of gguf-tools, which has no releases.
      (let ((gguflib
             (origin
               (method git-fetch)
               (uri (git-reference
                     (url "https://github.com/Lourdle/gguf-tools")
                     (commit "bac796ada809ac293e685db59b075971181cb008")))
               (file-name "openvino-genai-gguflib-checkout")
               (sha256
                (base32
                 "13rqvabaa8p2chk1vv3nfrap3yz8hqzhprzj9wrn5cyq0i6270na")))))
        #~(list "-DENABLE_PYTHON=ON"
                ;; openvino-tokenizers is a separate package.
                "-DBUILD_TOKENIZERS=OFF"
                ;; These would download xgrammar and the misaki
                ;; dependencies at build time.
                "-DENABLE_XGRAMMAR=OFF"
                "-DENABLE_MISAKI_CPP=OFF"
                "-DENABLE_JS=OFF"
                "-DENABLE_SAMPLES=OFF"
                "-DENABLE_TESTS=OFF"
                "-DENABLE_TOOLS=OFF"
                "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
                (string-append "-DFETCHCONTENT_SOURCE_DIR_GGUFLIB="
                               #$gguflib)
                (string-append "-DFETCHCONTENT_SOURCE_DIR_SAFETENSORS.H="
                               #$(this-package-input "safetensors-h")
                               "/include")))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'use-guix-dependencies
            (lambda _
              ;; Use nlohmann-json, minja and pybind11 from Guix instead of
              ;; downloading them.
              (substitute* "src/cpp/CMakeLists.txt"
                (("if\\(NOT TARGET nlohmann_json\\)")
                 (string-append
                  "find_package(nlohmann_json REQUIRED)\n"
                  "if(NOT TARGET nlohmann_json::nlohmann_json)"))
                (("if\\(NOT TARGET minja\\)" all)
                 (string-append "add_library(minja INTERFACE)\n"
                                "target_link_libraries(minja INTERFACE"
                                " nlohmann_json::nlohmann_json)\n"
                                all)))
              (substitute* "src/python/CMakeLists.txt"
                (("if \\(NOT TARGET pybind11::pybind11\\)" all)
                 (string-append "set(PYBIND11_FINDPYTHON ON)\n"
                                "find_package(pybind11 REQUIRED)\n"
                                all)))))
          (add-after 'unpack 'use-gnu-layout
            (lambda _
              ;; Upstream installs into runtime/{lib,bin,include,cmake} and
              ;; the Python module into python/.
              (substitute* "src/CMakeLists.txt"
                (("runtime/lib/\\$\\{ARCH_DIR\\}") "lib")
                (("runtime/bin/\\$\\{ARCH_DIR\\}") "bin"))
              (substitute* "src/cpp/CMakeLists.txt"
                (("runtime/include") "include")
                (("runtime/cmake") "lib/cmake/OpenVINOGenAI"))
              (substitute* "src/python/CMakeLists.txt"
                (("DESTINATION python/openvino_genai")
                 (string-append
                  "DESTINATION lib/python"
                  #$(version-major+minor (package-version python))
                  "/site-packages/openvino_genai"))
                ;; libopenvino_genai.so is not next to the Python module.
                (("set\\(py_rpaths \"\\$ORIGIN\"\\)")
                 "set(py_rpaths \"${CMAKE_INSTALL_PREFIX}/lib\")"))))
          (add-after 'unpack 'locate-tokenizers
            (lambda* (#:key inputs #:allow-other-keys)
              ;; Upstream expects the tokenizers extension next to
              ;; libopenvino_genai.so.
              (substitute* "src/cpp/src/tokenizer/tokenizers_path.cpp"
                (("return with_openvino_tokenizers\\(get_ov_genai_library.*")
                 (string-append
                  "return \""
                  (search-input-file
                   inputs
                   (string-append
                    "lib/python"
                    #$(version-major+minor (package-version python))
                    "/site-packages/openvino_tokenizers/lib"
                    "/libopenvino_tokenizers.so"))
                  "\";\n")))))
          (add-after 'install 'move-documentation
            (lambda _
              ;; Upstream installs samples and licenses at the top level.
              (let ((doc (string-append #$output "/share/doc/"
                                        #$name "-" #$version)))
                (mkdir-p doc)
                (for-each (lambda (directory)
                            (rename-file
                             (string-append #$output "/" directory)
                             (string-append doc "/" directory)))
                          '("samples" "docs")))))
          (delete 'check)
          (add-after 'install 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "GUIX_PYTHONPATH"
                        (string-append
                         #$output "/lib/python"
                         #$(version-major+minor (package-version python))
                         "/site-packages:" (getenv "GUIX_PYTHONPATH")))
                (invoke "python3" "-c"
                        (string-append
                         "import openvino_genai;"
                         "print(openvino_genai.get_version())"))))))))
    (native-inputs (list pybind11))
    (inputs (list minja
                  nlohmann-json
                  opencl-clhpp
                  opencl-headers
                  opencl-icd-loader
                  openvino
                  python
                  safetensors-h))
    (propagated-inputs (list openvino-tokenizers python-openvino))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/openvinotoolkit/openvino.genai")
    (synopsis "Generative AI pipelines for OpenVINO")
    (description
     "OpenVINO GenAI provides pipelines for generative AI models on top of
OpenVINO, such as text generation with large language models, visual language
models, image generation and speech recognition.  It supports speculative
decoding, including DFlash, and comes with C++ and Python APIs.")
    (license license:asl2.0)))


(define-public openvino-tokenizers
  (package
    (name "openvino-tokenizers")
    ;; Keep in sync with the version of openvino.
    (version "2026.4.1.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/openvinotoolkit/openvino_tokenizers")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1a5b585ay732r68kzi4j57b3azaw5dr7c805j0sjy060jgdxcr6n"))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:build-type "Release"
      ;; The test suite converts tokenizers of Hugging Face models downloaded
      ;; from the network; 'check' only checks that the extension loads.
      #:configure-flags
      #~(list
         ;; Use the same layout as the Python wheel, where the Python module
         ;; looks for the extension.
         (string-append "-DOPENVINO_TOKENIZERS_INSTALL_LIBDIR=lib/python"
                        #$(version-major+minor (package-version python))
                        "/site-packages/openvino_tokenizers/lib")
         ;; The extension needs internal SentencePiece headers, so it is
         ;; built from the source of the sentencepiece package.
         (string-append "-DFETCHCONTENT_SOURCE_DIR_SENTENCEPIECE="
                        #$(package-source sentencepiece))
         "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
         ;; Conversion extensions for the ONNX frontend are registered
         ;; unconditionally; their header-only definitions are taken from
         ;; the OpenVINO source, as openvino is built without that frontend.
         (string-append "-DCMAKE_CXX_FLAGS=-I"
                        #$(package-source openvino)
                        "/src/frontends/onnx/frontend/include"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'use-system-pcre2
            (lambda _
              ;; Link against PCRE2 from Guix instead of downloading it.
              (substitute* "src/CMakeLists.txt"
                (("FetchContent_GetProperties\\(pcre2\\)")
                 (string-append
                  "find_package(PkgConfig REQUIRED)\n"
                  "  pkg_check_modules(PCRE2 REQUIRED IMPORTED_TARGET"
                  " libpcre2-8)\n"
                  "  set(pcre2_POPULATED TRUE)"))
                (("PRIVATE pcre2-8\\)")
                 "PRIVATE PkgConfig::PCRE2)"))))
          (replace 'install
            (lambda _
              (let ((site (string-append
                           #$output "/lib/python"
                           #$(version-major+minor (package-version python))
                           "/site-packages/openvino_tokenizers")))
                (invoke "cmake" "--install" "."
                        "--component" "openvino_tokenizers")
                ;; The Python module is normally copied by the
                ;; py-build-cmake backend.
                (copy-recursively "../source/python/openvino_tokenizers"
                                  site)
                (install-file "python/__version__.py" site))))
          (add-after 'install 'install-metadata
            (lambda _
              ;; Python packages that require openvino-tokenizers, such as
              ;; optimum-intel, look for the metadata of its wheel.
              (let ((dist-info
                     (string-append
                      #$output "/lib/python"
                      #$(version-major+minor (package-version python))
                      "/site-packages/openvino_tokenizers-" #$version
                      ".dist-info")))
                (mkdir-p dist-info)
                (call-with-output-file (string-append dist-info "/METADATA")
                  (lambda (port)
                    (format port "Metadata-Version: 2.1~%")
                    (format port "Name: openvino-tokenizers~%")
                    (format port "Version: ~a~%" #$version))))))
          (delete 'check)
          (add-after 'install 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "GUIX_PYTHONPATH"
                        (string-append
                         #$output "/lib/python"
                         #$(version-major+minor (package-version python))
                         "/site-packages:" (getenv "GUIX_PYTHONPATH")))
                (invoke "python3" "-c"
                        (string-append
                         "import openvino, openvino_tokenizers;"
                         "openvino.Core().add_extension("
                         "str(openvino_tokenizers._ext_path))"))))))))
    (native-inputs (list pkg-config))
    (inputs (list openvino pcre2 python))
    (propagated-inputs (list python-openvino))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/openvinotoolkit/openvino_tokenizers")
    (synopsis "Tokenizers for OpenVINO")
    (description
     "OpenVINO Tokenizers adds text processing operations to OpenVINO, so
that the tokenizers and detokenizers of Hugging Face models can run as
OpenVINO models.  It consists of an OpenVINO extension library and a Python
module to load it and to convert tokenizers.")
    ;; The extension bundles SentencePiece, also under the Apache 2.0 license.
    (license license:asl2.0)))

(define-public ovms
  (package
    (name "ovms")
    ;; Keep in sync with the version of openvino.
    (version "2026.4.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/openvinotoolkit/model_server")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0gy0p0ysvw7ii276m5c1s0x3s36f9bv3xh9d8qj36jqj7q5ynyn2"))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:build-type "Release"
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'add-cmake-build
            ;; Upstream builds with Bazel; this CMake file builds the same
            ;; configuration, without Python and cloud storage.
            (lambda _
              (copy-file #$(local-file "../../aux-files/ovms/CMakeLists.txt")
                         "CMakeLists.txt")))
          (add-after 'unpack 'unpack-mediapipe
            ;; OVMS' fork of MediaPipe; only the framework and the core
            ;; calculators are built.
            (lambda _
              (copy-recursively
               #$(origin
                   (method git-fetch)
                   (uri (git-reference
                         (url "https://github.com/openvinotoolkit/mediapipe")
                         (commit "12e8d511cfbc5f471c498278a65a02dd250963e8")))
                   (file-name "ovms-mediapipe-checkout")
                   (sha256
                    (base32
                     "05zlwlpa5wz3sw1c02pgl9vhiwp68pday71glm2xldp1ykzry379")))
               "mediapipe")
              (for-each make-file-writable
                        (find-files "mediapipe" #:directories? #t))))
          (add-after 'unpack-mediapipe 'adjust-mediapipe
            (lambda _
              (with-directory-excursion "mediapipe/mediapipe/framework"
                ;; Formerly included through the Protobuf 3 headers.
                (substitute* "deps/re2.h"
                  (("^#include <regex>" all)
                   (string-append "#include <mutex>\n" all)))
                ;; Protobuf 6 API.
                (substitute* "tool/template_parser.cc"
                  (("error_collector_->Add(Error|Warning)\\(" _ kind)
                   (string-append "error_collector_->Record" kind "("))
                  (("virtual void Add(Error|Warning)\\(int line, int column, \
const std::string& message\\)" _ kind)
                   (string-append "void Record" kind "(int line, int column, "
                                  "absl::string_view message) override"))
                  (("reflection->SupportsUnknownEnumValues\\(\\)")
                   "!field->legacy_enum_field_treated_as_closed()")
                  ;; Internal to Protobuf 6 and not exported by it.
                  (("^using proto_ns::internal::GetAnyFieldDescriptors;")
                   "\
inline bool GetAnyFieldDescriptors(const proto_ns::Message& message,
                                   const proto_ns::FieldDescriptor** type_url,
                                   const proto_ns::FieldDescriptor** value) {
  const proto_ns::Descriptor* descriptor = message.GetDescriptor();
  if (descriptor->full_name() != \"google.protobuf.Any\") return false;
  *type_url = descriptor->FindFieldByNumber(1);
  *value = descriptor->FindFieldByNumber(2);
  return *type_url != nullptr &&
         (*type_url)->type() == proto_ns::FieldDescriptor::TYPE_STRING &&
         *value != nullptr &&
         (*value)->type() == proto_ns::FieldDescriptor::TYPE_BYTES;
}")))))
          (add-after 'unpack 'adjust-sources
            (lambda _
              (with-directory-excursion "src"
                (substitute* "version.hpp"
                  (("REPLACE_PROJECT_VERSION") #$version)
                  (("REPLACE_BAZEL_BUILD_FLAGS") "none (CMake build)"))
                ;; Protobuf 6 API.
                (substitute* "http_rest_api_handler.cpp"
                  (("google::protobuf::util::Status status")
                   "absl::Status status")
                  (("always_print_primitive_fields")
                   "always_print_fields_with_no_presence"))
                ;; Abseil's inline namespace breaks this forward declaration.
                (substitute* "audio/speech_to_text/s2t_servable.hpp"
                  (("^namespace absl \\{\n") "")
                  (("^class Status;\n")
                   "#include \"absl/status/status.h\"\n")
                  (("^\\}  // namespace absl\n") ""))
                ;; Bazel provided it indirectly.
                (substitute* "schema.cpp"
                  (("^#include <utility>" all)
                   (string-append all "\n#include <sys/stat.h>")))
                ;; Unused header from model_api, which is not packaged.
                (substitute* '("embeddings/embeddings_calculator_ov.cc"
                               "rerank/rerank_calculator_ov.cc")
                  (("^#include <adapters/inference_adapter.h>") ""))
                ;; Make TensorFlow tensors in MediaPipe graphs optional, as
                ;; there is no TensorFlow library to build against.
                (substitute* "kfs_frontend/kfs_graph_executor_impl.cpp"
                  (("^#include \"\\.\\./tensorflow_type_utils\\.hpp\"\n" all)
                   (string-append "#if (TFTENSOR_DISABLE == 0)\n" all
                                  "#endif\n"))
                  ;; Only after 'template <>', which the next specialization
                  ;; then uses.
                  (("^Status receiveAndSerializePacket<tensorflow::Tensor>"
                    all)
                   (string-append "#if (TFTENSOR_DISABLE == 0)\n" all))
                  (("^Status receiveAndSerializePacket<::mediapipe::Tensor>"
                    all)
                   (string-append "#endif\n" all))
                  (("^static Status deserializeTensor\\(.*\
std::unique_ptr<tensorflow::Tensor>" all)
                   (string-append "#if (TFTENSOR_DISABLE == 0)\n" all))
                  (("^static Status deserializeTensor\\(.*\
std::unique_ptr<ov::Tensor>" all)
                   (string-append "#endif\n" all))
                  (("^( *)status = [a-zA-Z]+<tensorflow::Tensor.*\n"
                    all indent)
                   (string-append
                    "#if (TFTENSOR_DISABLE == 0)\n" all "#else\n"
                    indent "status = Status(StatusCode::NOT_IMPLEMENTED,\n"
                    indent "    \"TensorFlow tensors are disabled\");\n"
                    "#endif\n"))))))
          (add-after 'adjust-sources 'locate-tokenizers
            (lambda _
              (let ((tokenizers #$(this-package-input "openvino-tokenizers")))
                (substitute* "src/servable_management/modelmanager.cpp"
                  (("\"libopenvino_tokenizers\\.so\"")
                   (string-append
                    "\""
                    (car (find-files tokenizers
                                     "^libopenvino_tokenizers\\.so$"))
                    "\""))))))
          (replace 'check
            ;; The test suite needs Bazel, test models and network access.
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (invoke "./ovms" "--version")))))))
    (native-inputs (list pkg-config))
    (inputs (list abseil-cpp
                  brotli
                  c-ares
                  cpp-httplib
                  curl
                  cxxopts
                  dr-libs
                  drogon-for-ovms
                  eigen
                  flatbuffers-23.5
                  fmt
                  glog
                  grpc
                  libgit2-for-ovms
                  libva
                  minitrace
                  nlohmann-json
                  opencl-clhpp
                  opencl-headers
                  opencl-icd-loader
                  opencv
                  openssl
                  openvino
                  openvino-genai
                  openvino-tokenizers
                  prometheus-cpp
                  protobuf-6
                  rapidjson
                  re2-next
                  spdlog
                  stb-image
                  stb-image-write
                  tensorflow-lite
                  (list util-linux "lib")
                  zlib))
    ;; openvino loads the GPU and NPU drivers, but ovms does not propagate it.
    (native-search-paths (package-native-search-paths openvino))
    (supported-systems '("x86_64-linux"))
    (home-page "https://github.com/openvinotoolkit/model_server")
    (synopsis "Inference server for OpenVINO models")
    (description
     "OpenVINO Model Server (OVMS) serves models optimized with OpenVINO over
the KServe gRPC and REST APIs and over OpenAI-compatible endpoints for chat
and text completions, embeddings, reranking, image generation and speech.
Pipelines are described as MediaPipe graphs.  It can pull models from Hugging
Face.  This package is built without Python nodes and without cloud
storage.")
    (license license:asl2.0)))

(define-public python-nncf
  (package
    (name "python-nncf")
    (version "3.4.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/openvinotoolkit/nncf")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1skywpnwdnvnhw01wq8843l5sykxj8ma9li4zp7vjkp6n62jghiy"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      ;; The backend tests need timm and models from the network.
      #:test-flags
      #~(list "tests/common" "-k"
              (string-join
               (list
                ;; networkx 3.4.2 cannot read DOT files with pydot 4.
                "not test_read_dot_file_gives_graph_with_colons"
                "not test_find_constant_subgraphs"
                "not test_remove_noop_operation_nodes"
                ;; openvino-telemetry is not packaged.
                "not test_telemetry_is_not_mocked_in_normal_conditions")
               " and "))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'relax-requirements
            (lambda _
              ;; openvino-telemetry is imported optionally, with a stub as
              ;; fallback.  The ninja Python module is never imported; PyTorch
              ;; extensions only need the ninja command.
              (substitute* "pyproject.toml"
                ((".*\"(ninja|openvino-telemetry)[<>=].*") ""))))
          (add-before 'build 'set-version
            (lambda _
              ;; Otherwise the version is extended with the Git commit.
              (setenv "NNCF_RELEASE_BUILD" "1"))))))
    (propagated-inputs
     (list python-networkx
           python-numpy
           python-packaging
           python-psutil
           python-pydot
           python-rich
           python-safetensors
           python-scikit-learn
           python-scipy
           python-tabulate))
    (native-inputs
     (list python-pytest
           python-pytest-mock
           python-setuptools))
    (home-page "https://github.com/openvinotoolkit/nncf")
    (synopsis "Neural network compression framework")
    (description
     "NNCF provides algorithms for optimizing the inference of neural
networks, such as post-training quantization, weight compression and
quantization-aware training.  It supports models of OpenVINO, PyTorch and
ONNX.")
    (license license:asl2.0)))

(define-public python-openvino
  (package
    (inherit openvino)
    (name "python-openvino")
    (outputs '("out"))
    (arguments
     (list
      #:build-type "Release"
      ;; There are no CTest tests; 'check' runs after 'install' instead.
      #:configure-flags
      #~(let ((developer (search-input-directory %build-inputs
                                                 "developer_package")))
          (list "-DCPACK_GENERATOR=CONDA-FORGE" ;GNU installation layout
                (string-append "-DOpenVINODeveloperPackage_DIR="
                               developer "/cmake")
                ;; Do not keep a reference to the "developer" output, which
                ;; is only needed at build time, through __FILE__.
                (string-append "-DCMAKE_CXX_FLAGS=-ffile-prefix-map="
                               developer "=developer_package")
                "-DENABLE_PYTHON=ON"
                "-DENABLE_WHEEL=OFF"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'chdir
            (lambda _
              ;; Build only the bindings, against the installed OpenVINO.
              (chdir "src/bindings/python")))
          (add-after 'chdir 'find-ittapi
            (lambda _
              ;; The developer package refers to ittapi::ittnotify without
              ;; looking for ittapi itself.
              (substitute* "CMakeLists.txt"
                (("find_package\\(OpenVINODeveloperPackage REQUIRED\\)" all)
                 (string-append "find_package(ittapi REQUIRED)\n    "
                                all)))))
          (add-before 'configure 'set-version
            (lambda _
              ;; The bindings refuse to load unless their build number
              ;; matches that of libopenvino.so.
              (setenv "CI_BUILD_NUMBER"
                      (string-append #$(package-version openvino)
                                     "-000-guix"))))
          (replace 'install
            (lambda _
              ;; The Python components are excluded from the default
              ;; installation.
              (invoke "cmake" "--install" "." "--component"
                      (string-append
                       "pyopenvino_python"
                       #$(version-major+minor (package-version python))))
              ;; The model conversion API (convert_model), which the wheel
              ;; includes, is a separate CMake project in tools/ovc.
              (copy-recursively
               "../../../tools/ovc/openvino/tools/ovc"
               (string-append
                #$output "/lib/python"
                #$(version-major+minor (package-version python))
                "/site-packages/openvino/tools/ovc"))))
          (add-after 'install 'install-metadata
            (lambda _
              ;; Python packages that require openvino, such as
              ;; optimum-intel, look for the metadata of its wheel.
              (let ((dist-info
                     (string-append
                      #$output "/lib/python"
                      #$(version-major+minor (package-version python))
                      "/site-packages/openvino-"
                      #$(package-version openvino) ".dist-info")))
                (mkdir-p dist-info)
                (call-with-output-file (string-append dist-info "/METADATA")
                  (lambda (port)
                    (format port "Metadata-Version: 2.1~%Name: openvino~%")
                    (format port "Version: ~a~%"
                            #$(package-version openvino)))))))
          (delete 'check)
          (add-after 'install 'check
            (lambda* (#:key tests? #:allow-other-keys)
              (when tests?
                (setenv "GUIX_PYTHONPATH"
                        (string-append
                         #$output "/lib/python"
                         #$(version-major+minor (package-version python))
                         "/site-packages:" (getenv "GUIX_PYTHONPATH")))
                (invoke "python3" "-c"
                        (string-append "import openvino;"
                                       "print(openvino.get_version());"
                                       "openvino.Core();"
                                       "openvino.convert_model"))))))))
    (native-inputs (list pybind11 (list openvino "developer")))
    (inputs (list ittapi openvino pugixml python))
    (propagated-inputs (list python-numpy))
    (synopsis "Python bindings for OpenVINO")
    (description
     "This package provides the Python API of OpenVINO, a toolkit for
optimizing and deploying deep learning models on CPUs, Intel GPUs and the NPU
of Intel CPUs.")
    (license license:asl2.0)))

(define-public python-optimum-intel
  ;; The latest release, 2.2.0, exports Qwen3.5 models only with transformers
  ;; 5.2 and Gemma 4 models only from transformers 5.5 on; this commit
  ;; exports both with transformers 5.15.
  (let ((commit "0100bb36ea09fe8613008ee74cb796dc5e1c379d")
        (revision "0"))
    (package
      (name "python-optimum-intel")
      (version (git-version "2.3.0.dev0" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/huggingface/optimum-intel")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "0877dxw2y3brfqycslph9vvc0p41dpxnx6cxzrbhml7i9bax6zps"))))
      (build-system pyproject-build-system)
      (arguments
       (list
        #:phases
        #~(modify-phases %standard-phases
            (add-after 'unpack 'skip-git-version
              (lambda _
                ;; setup.py appends the output of "git rev-parse" to
                ;; development versions; the commit is in the Guix version.
                (substitute* "setup.py"
                  (("__version__\\.endswith\\(\"\\.dev0\"\\)") "False"))))
            (replace 'check
              (lambda* (#:key tests? #:allow-other-keys)
                ;; The test suite needs models from the Hugging Face Hub;
                ;; check that the installed OpenVINO backend and its command
                ;; load.
                (when tests?
                  (with-directory-excursion "/tmp"
                    (invoke "python3" "-c"
                            (string-append
                             "from optimum.intel import OVModelForCausalLM;"
                             "from optimum.intel.utils import import_utils"
                             " as u;"
                             "assert u.is_nncf_available();"
                             "assert u.is_openvino_tokenizers_available()"))
                    (invoke (string-append #$output "/bin/optimum-cli")
                            "export" "openvino" "--help"))))))))
      (propagated-inputs
       (list openvino-tokenizers
             python-huggingface-hub
             python-nncf
             python-openvino
             python-optimum
             python-pytorch
             python-requests
             python-torchvision
             python-transformers))
      (native-inputs (list python-setuptools))
      (home-page "https://github.com/huggingface/optimum-intel")
      (synopsis "OpenVINO backend for Hugging Face Optimum")
      (description
       "Optimum Intel connects Hugging Face Transformers and Diffusers with
OpenVINO.  It exports models to the OpenVINO format, compresses and quantizes
them with NNCF, and runs them through classes such as
@code{OVModelForCausalLM}, which replace their Transformers counterparts.  It
adds the @command{optimum-cli export openvino} command.")
      (license license:asl2.0))))

(define-public vc-intrinsics
  (package
    (inherit (@ (gnu packages oneapi) vc-intrinsics))
    (version "0.26.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/intel/vc-intrinsics")
             (commit (string-append "v" version))))
       (file-name (git-file-name "vc-intrinsics" version))
       (sha256
        (base32 "1rah6vlv9niqs8lmv21dlmjz7b60y2lc22wg3r2wnanfh4jrgb8l"))))
    ;; The latest LLVM; Intel Graphics Compiler and DPC++ build this
    ;; package from its source with their own LLVM.
    (inputs
     (modify-inputs inputs (replace "llvm" llvm-23)))))

(define-public xpumanager
  (package
    (name "xpumanager")
    (version "2.3.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/intel/xpumanager")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1x73c79vqr26wn4x6iy1hscm890ai7acnwfzm7c8nczfcw3hn8rs"))))
    (build-system meson-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list
         ;; Upstream sets werror=true, but GCC warns about the result of
         ;; write(2) even when a test casts it to void; keep that one a
         ;; warning.
         "-Dcpp_args=-Wno-error=unused-result"
         ;; Upstream leaves the unit tests out by default, as they need
         ;; doctest; it is a native input here.
         "-Dwith_tests=true")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'fix-paths
            (lambda* (#:key inputs #:allow-other-keys)
              ;; The PCI ID database is not in /usr/share/hwdata, and
              ;; /bin/sh does not exist in the build environment; the
              ;; crash log tools and the collection of debug logs run
              ;; commands with "sh -c".
              (substitute* "oal/lin/pci_database.cpp"
                (("\"/usr/share/hwdata/pci.ids\"")
                 (string-append "\""
                                (search-input-file inputs
                                                   "share/hwdata/pci.ids")
                                "\"")))
              (substitute* "oal/lin/lin.cpp"
                (("\"/bin/sh\"")
                 (string-append "\"" (search-input-file inputs "bin/sh")
                                "\""))))))))
    (native-inputs (list cmake-minimal doctest pkg-config python))
    (inputs (list bash-minimal
                  cli11
                  curl
                  eudev
                  fmt
                  hwdata
                  `(,hwloc "lib")
                  igsc
                  level-zero/driver-path
                  libpciaccess
                  metee
                  nlohmann-json))
    ;; Let the loader find the driver, such as intel-compute-runtime, when
    ;; both are in the same profile.
    (native-search-paths
     (package-native-search-paths level-zero/driver-path))
    (home-page "https://github.com/intel/xpumanager")
    (synopsis "Monitoring and management tool for Intel GPUs")
    (description
     "XPU Manager monitors and manages Intel GPUs, both integrated and
discrete, such as the Arc and Data Center series.  Despite its name, it does
not handle NPUs or CPUs.  Its command @command{xpu-smi} shows the devices,
their firmware versions and topology, reports telemetry such as utilization,
power, frequency, temperature and memory use, and changes settings such as
power limits and frequency ranges.  It can also update the GPU firmware
through @code{libigsc}.")
    (license license:expat)))
