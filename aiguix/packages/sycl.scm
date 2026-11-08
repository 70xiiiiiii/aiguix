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
;;; Libraries written in SYCL and built with DPC++.  Guix has no module for
;;; them; this one keeps them apart from (aiguix packages oneapi), which
;;; DPC++ itself builds on.
;;;
;;; Code:

(define-module (aiguix packages sycl)
  #:use-module (guix build-system cmake)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (gnu packages check)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages logging)
  #:use-module (gnu packages machine-learning)
  #:use-module (gnu packages mpi)
  #:use-module ((gnu packages oneapi) #:select (onednn umf))
  #:use-module (gnu packages opencl)
  #:use-module (gnu packages parallel)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages profiling)
  #:use-module (gnu packages python)
  #:use-module (aiguix packages oneapi)
  #:use-module (aiguix packages llvm))

(define-public onemath
  (package
    (name "onemath")
    (version "0.9")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/uxlfoundation/oneMath")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1vvs0j49s5nbycb2c664gcak4wb5yd7861slaag26fxsfyk2nmwd"))))
    (build-system cmake-build-system)
    (arguments
     (list
      ;; The tests need a SYCL device, such as an Intel GPU.
      #:tests? #f
      #:configure-flags
      #~(list
         ;; The oneMKL backends are nonfree; use the generic SYCL
         ;; backends instead, which run on any SYCL device.  No
         ;; portFFT backend for DFT: portFFT uses the sub-group load
         ;; and store of SYCL, which DPC++ 7 removed.
         "-DENABLE_MKLCPU_BACKEND=OFF"
         "-DENABLE_MKLGPU_BACKEND=OFF"
         "-DENABLE_GENERIC_BLAS_BACKEND=ON"
         ;; Both are built by default: the tests cannot run here, and
         ;; the examples are not installed.
         "-DBUILD_FUNCTIONAL_TESTS=OFF"
         "-DBUILD_EXAMPLES=OFF"
         ;; The compilers of DPC++.  Without these flags, the build
         ;; first looks for icx and icpx, the compilers of Intel
         ;; oneAPI, in PATH.
         "-DCMAKE_C_COMPILER=clang"
         "-DCMAKE_CXX_COMPILER=clang++"
         ;; Sources that the build would otherwise fetch.  There are
         ;; no releases of generic-sycl-components; the build takes
         ;; its main branch, at this commit for oneMath 0.9.
         (string-append
          "-DFETCHCONTENT_SOURCE_DIR_ONEMATH_SYCL_BLAS="
          #$(origin
              (method git-fetch)
              (uri (git-reference
                    (url (string-append "https://github.com/"
                                        "uxlfoundation/"
                                        "generic-sycl-components"))
                    (commit "99241128f64b700392e4cfdd047caada024bf7dd")))
              (sha256
               (base32
                "0rm4pgfn5l2w5nnhgi724an2xp2gzidn0wzyjkjslml9a1r9d314"))
              (file-name "generic-sycl-components-for-onemath"))))))
    (native-inputs (list dpcpp))
    (home-page "https://github.com/uxlfoundation/oneMath")
    (synopsis "SYCL interface for math routines")
    (description
     "oneMath provides a SYCL interface for math routines such as BLAS,
LAPACK, random number generators and discrete Fourier transforms, and runs
them through a backend for the device.  This package has the generic BLAS
backend of @code{generic-sycl-components}, which runs on any SYCL device,
such as Intel GPUs through DPC++.")
    (license license:asl2.0)))

(define-public oneccl
  (package
    (name "oneccl")
    (version "2022.2.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/uxlfoundation/oneCCL")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0h7lndidjnxr4ivm6cr1imc9b7r4i7k7pc1i2f8rwwqvakdvzxvr"))
       (modules '((guix build utils)))
       ;; oneCCL bundles prebuilt binaries of Intel MPI and libfabric, and
       ;; copies of hwloc, ITT, Level Zero, PMIx and UMF.  Remove them;
       ;; 'use-system-libraries points the build to the inputs instead.
       (snippet
        #~(with-directory-excursion "deps/libccl/deps"
            (for-each delete-file-recursively
                      '("hwloc" "itt" "level_zero" "mpi" "ofi" "pmix"
                        "umf"))))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list
         ;; The compilers of DPC++, for the SYCL code; else CMake would
         ;; take GCC.
         "-DCMAKE_C_COMPILER=clang"
         "-DCMAKE_CXX_COMPILER=clang++"
         ;; ITT from Guix instead of the Git submodule, whose directory
         ;; the build looks for the headers in.
         (string-append "-Dittapi_SOURCE_DIR="
                        #$(this-package-input "ittapi"))
         ;; Only the tests of the API, which need no GPU and no MPI
         ;; processes.
         "-DONECCL_TEST_USE_MPI=OFF"
         "-DONECCL_LIBCCL_BUILD_FT=OFF"
         "-DONECCL_LIBCCL_BUILD_EXAMPLES=OFF"
         "-DONECCL_LIBCCL_BUILD_REG_TESTS=OFF")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'use-system-libraries
            (lambda* (#:key inputs #:allow-other-keys)
              ;; ITT and GoogleTest are Git submodules, which git-fetch
              ;; does not fetch: drop them from the build, and let the
              ;; tests use GoogleTest from Guix, whose CMake targets are
              ;; GTest::gtest and GTest::gtest_main.
              (substitute* "deps/CMakeLists.txt"
                (("^ *(require_submodule|add_subdirectory)\\((ittapi\
|googletest).*") ""))
              (substitute* "tests/CMakeLists.txt"
                (("^function\\(add_test_internal\\)" all)
                 (string-append "find_package(GTest REQUIRED)\n" all))
                (("^( +)(gtest|gtest_main)\n" _ indentation target)
                 (string-append indentation "GTest::" target "\n")))
              ;; The CPU plugin, lib/ccl/cpu/lib/libccl.so.1, links to
              ;; libccl.so.2 in lib/ of this package; add that directory
              ;; to its RUNPATH.
              (substitute* "CMakeLists.txt"
                (("-l:libccl\\.so\\.2 \\$\\{STATIC_INTEL_FLAG\\}" all)
                 (string-append all " -Wl,-rpath," #$output "/lib")))
              ;; DT_RPATH lets the CPU libccl.so.1 win over one in
              ;; LD_LIBRARY_PATH; use DT_RUNPATH as everywhere in Guix.
              (substitute* "plugins/legacy_cpu/CMakeLists.txt"
                (("\"-Wl,--disable-new-dtags\"") ""))
              ;; The build looks for the dependencies in the directory
              ;; that the snippet emptied; point it to the inputs.
              (with-directory-excursion "deps/libccl"
                (substitute* "CMakeLists.txt"
                  (("\\$\\{DEPS_DIR\\}/itt/lib64")
                   (string-append #$(this-package-input "ittapi") "/lib"))
                  (("\\$\\{DEPS_DIR\\}/level_zero/include")
                   (string-append #$(this-package-input "level-zero")
                                  "/include/level_zero"))
                  (("\\$\\{DEPS_DIR\\}/(hwloc|itt|mpi|ofi|pmix|umf)"
                    _ dependency)
                   (assoc-ref `(("hwloc"
                                 . ,(ungexp (this-package-input "hwloc")
                                            "lib"))
                                ("itt" . ,#$(this-package-input "ittapi"))
                                ("mpi" . ,#$(this-package-input "mpich"))
                                ("ofi" . ,#$(this-package-input "libfabric"))
                                ("pmix" . ,#$(this-package-input "openpmix"))
                                ("umf" . ,#$(this-package-input "umf")))
                              dependency)))
                (substitute* "src/CMakeLists.txt"
                  ;; hwloc of Guix has no static library.
                  (("libhwloc\\.a") "libhwloc.so")
                  ;; Do not install the bundled libfabric, which the snippet
                  ;; removed.
                  (("if \\(\"\\$\\{LIBFABRIC_DIR\\}\" STREQUAL \"\"\\)")
                   "if(FALSE)"))
                ;; libccl opens these with dlopen when it starts; give it
                ;; their file names in the store, as there is no /usr/lib.
                (substitute* (find-files "src/common/api_wrapper"
                                         "\\.cpp$")
                  (("\"(libze_loader\\.so|libpmix\\.so|libmpi\\.so\\.12\
|libfabric\\.so\\.1)\"" _ library)
                   (string-append
                    "\"" (search-input-file inputs
                                            (string-append "lib/" library))
                    "\""))))))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              ;; The tests are registered for the CTest configuration
              ;; unit_tests only; plain ctest finds none.
              (when tests?
                (invoke "ctest" "--output-on-failure" "-C" "unit_tests")))))))
    (native-inputs (list dpcpp googletest))
    (inputs
     (list `(,hwloc "lib")
           ittapi
           level-zero/driver-path
           libfabric
           mpich
           openpmix
           umf))
    (home-page "https://github.com/uxlfoundation/oneCCL")
    (synopsis "Collective communication library for deep learning")
    (description
     "@acronym{oneCCL, oneAPI Collective Communications Library} provides
collective operations such as all-reduce, all-gather and broadcast between
processes that train or run neural networks, on CPUs and on Intel GPUs
through SYCL.  It is the backend of the @code{xccl} process group of PyTorch.
It transports data through libfabric or MPI.")
    (license license:asl2.0)))

(define-public onednn-sycl
  (package
    (inherit onednn)
    (name "onednn-sycl")
    (arguments
     (substitute-keyword-arguments (package-arguments onednn)
       ((#:configure-flags flags)
        ;; After the flags of onednn, so that ONEDNN_BUILD_GRAPH=ON
        ;; overrides their OFF.
        #~(append #$flags
                  (list (string-append "-DCMAKE_C_COMPILER="
                                       #$(file-append dpcpp "/bin/clang"))
                        (string-append "-DCMAKE_CXX_COMPILER="
                                       #$(file-append dpcpp "/bin/clang++"))
                        "-DDNNL_GPU_RUNTIME=SYCL"
                        ;; The graph API, which PyTorch uses for attention
                        ;; on Intel GPUs.
                        "-DONEDNN_BUILD_GRAPH=ON")))
       ;; These need a SYCL device, such as a supported Intel GPU, which
       ;; the build environment lacks.
       ((#:test-exclude _ "") "_gpu$|^test_api_sycl$")
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'fix-cache-size-without-sysfs
              (lambda _
                ;; On hybrid CPUs, the cache sizes come from /sys, which the
                ;; build environment lacks; a size of 0 makes the CPU
                ;; primitives divide by zero.  Fall back to CPUID then, as
                ;; oneDNN does on CPUs that are not hybrid.  CPUID gives
                ;; the cache of the core that the thread runs on, P or E,
                ;; not the smallest one, so the blocking may be a little
                ;; worse; the results stay correct.
                (substitute* "src/cpu/x64/platform.cpp"
                  (("return min_cache_bytes;")
                   "return min_cache_bytes > 0 ? min_cache_bytes
        : get_per_core_cache_size_cpuid(level);"))))))))
    ;; DPC++ compiles the package, so it is a native input, as gfortran is
    ;; in Guix, although the library links to libsycl from it.
    (native-inputs
     (modify-inputs (package-native-inputs onednn)
       (prepend dpcpp)))
    ;; The OpenMP runtime of LLVM 23, the base of DPC++, for the CPU
    ;; runtime OMP of onednn; and the OpenCL loader, for the GPU kernels.
    (inputs
     (modify-inputs (package-inputs onednn)
       (prepend libomp-23 opencl-icd-loader)))
    (synopsis "Deep neural network library for CPUs and SYCL GPUs")
    (description
     "@acronym{OneDNN, OneAPI Deep Neural Network Library} is a cross-platform
performance library of basic building blocks for deep learning applications.
This variant is built with DPC++ and runs on Intel GPUs through SYCL as well
as on CPUs, and includes the graph API.")))

(define-public pti-gpu
  (package
    (name "pti-gpu")
    (version "1.2.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/intel/pti-gpu")
             (commit (string-append "pti-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "14nj520z4cycv78mza64bz30i3w6hga3vp82v7sbx46w5yffidi8"))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:configure-flags
      ;; The IDs of the Level Zero functions are for an older Level Zero;
      ;; add those of the newer functions, as upstream does on updates.
      #~(list "-DPTI_API_ID_REGENERATE=ON"
              "-DPTI_BUILD_SAMPLES=OFF"
              "-DPTI_BUILD_URGEMM=OFF")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'use-system-libraries
            (lambda _
              ;; The build would fetch ITT; take that of Guix, and the
              ;; internal headers that it uses from the source of ITT.
              (substitute* "sdk/cmake/Modules/macros.cmake"
                (("if \\(NOT TARGET ittapi::ittnotify OR NOT TARGET \
ittapi::headers\\)")
                 (string-append
                  "if (NOT TARGET ittapi::headers)\n"
                  "    find_package(ittapi REQUIRED)\n"
                  "    add_library(ittapi::headers INTERFACE IMPORTED)\n"
                  "    set_target_properties(ittapi::headers PROPERTIES"
                  " INTERFACE_INCLUDE_DIRECTORIES \""
                  #$(this-package-input "ittapi") "/include;"
                  #$(package-source ittapi) "/src/ittnotify\")\n"
                  "  endif()\n"
                  "  if (FALSE)")))
              ;; Both load the Level Zero loader at run time.
              (substitute* '("sdk/src/lz_api_tracing_api_loader.h"
                             "sdk/src/levelzero/ze_wrappers.h"
                             "sdk/src/metrics/metrics_handler.h"
                             "tools/unitrace/src/levelzero/ze_loader.h")
                (("\"libze_loader\\.so\\.1\"")
                 (string-append "\""
                                #$(this-package-input "level-zero")
                                "/lib/libze_loader.so.1\"")))
              ;; unitrace writes the Git commit into its version.
              (substitute* "tools/unitrace/scripts/get_commit_hash.py"
                ((".*subprocess\\.run\\(\\['git'.*") "")
                (("result\\.stdout\\[0:len\\(result\\.stdout\\) - 1\\]")
                 (string-append "\"pti-"
                                #$(package-version this-package) "\"")))))
          (add-after 'use-system-libraries 'change-directory
            (lambda _
              (chdir "sdk")))
          (replace 'check
            (lambda* (#:key tests? #:allow-other-keys)
              ;; The functional tests, and these unit tests, need an Intel
              ;; GPU.
              (when tests?
                (invoke "ctest" "--output-on-failure" "-L" "unit"
                        "-E" (string-append
                              "^(FlagCombinations|PcSamplingTest"
                              "|ZeEventPool(Manager|sObserver)?Test)")))))
          (add-after 'install 'install-unitrace
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((build (string-append (getcwd) "/../unitrace")))
                (mkdir-p build)
                ;; The scripts of unitrace clone these repositories into
                ;; the build directory unless they are there, and copy
                ;; headers from them; ITT is built from its source.
                (for-each
                 (lambda (directory source)
                   (copy-recursively source
                                     (string-append build "/" directory))
                   (for-each make-file-writable
                             (find-files (string-append build "/"
                                                        directory)
                                         #:directories? #t)))
                 '("compute-runtime" "level-zero" "ittapi")
                 (list #$(package-source intel-compute-runtime)
                       #$(package-source level-zero/driver-path)
                       #$(package-source ittapi)))
                (invoke "cmake" "-S" "../tools/unitrace" "-B" build
                        "-DCMAKE_BUILD_TYPE=Release"
                        (string-append "-DCMAKE_INSTALL_PREFIX=" #$output)
                        ;; libunitrace_mpi, for tracing MPI programs.
                        "-DBUILD_WITH_MPI=1"
                        ;; The output in the format of Perfetto needs a
                        ;; static libprotobuf with hidden symbols, since
                        ;; unitrace preloads its library into programs that
                        ;; may have their own protobuf.  Perfetto also reads
                        ;; the Chrome traces that unitrace writes.
                        "-DBUILD_WITH_PERFETTO=OFF")
                (invoke "cmake" "--build" build "--parallel"
                        (number->string (parallel-job-count)))
                (invoke "cmake" "--install" build)))))))
    (native-inputs
     (list googletest pkg-config python))
    (inputs
     (list dpcpp                        ;XPTI, for SYCL
           ittapi
           level-zero/driver-path
           libomp-23                    ;OMPT, for OpenMP offload
           mpich
           opencl-headers
           opencl-icd-loader
           spdlog))
    ;; As in dpcpp: let the Level Zero and OpenCL loaders find the
    ;; drivers, such as intel-compute-runtime, when both are in the same
    ;; profile.
    (native-search-paths
     (append (package-native-search-paths level-zero/driver-path)
             (package-native-search-paths opencl-icd-loader)))
    (home-page "https://github.com/intel/pti-gpu")
    (synopsis "Profiling and tracing for Intel GPUs")
    (description
     "PTI (Profiling Tools Interfaces for GPU) provides @code{libpti_view},
a library that records the activity of Intel GPUs through Level Zero, such as
kernels, memory copies and synchronization, for profilers such as that of
PyTorch.  It also provides @command{unitrace}, which traces programs that use
Level Zero, OpenCL or SYCL without changing them, and reports the time of
kernels and API calls, a timeline for Perfetto and hardware metrics.  It
also traces the MPI calls of programs run with @command{mpiexec}.
@command{unitrace} needs a Level Zero driver for Intel GPUs, such as
@code{intel-compute-runtime}, in the same profile, even for programs that do
not use the GPU.")
    (license license:expat)))

(define-public python-pytorch-xpu
  (package
    (inherit python-pytorch)
    (name "python-pytorch-xpu")
    (source
     (origin
       (inherit (package-source python-pytorch))
       (snippet
        #~(begin
            ;; The snippet of python-pytorch, which deletes third_party
            ;; among other bundled code.
            #$(origin-snippet (package-source python-pytorch))
            ;; torch-xpu-ops, the XPU operators, at the commit of
            ;; third_party/xpu.txt, which the build would clone with Git.
            (copy-recursively
             #$(origin
                 (method git-fetch)
                 (uri (git-reference
                       (url "https://github.com/intel/torch-xpu-ops")
                       (commit "60bb67cae89d267fee2040f3e4b18e2ad64055e8")))
                 (file-name "torch-xpu-ops-for-pytorch")
                 (sha256
                  (base32
                   "0f6izs9dpyrh6n7b1zjbm03983kyvqq8vg7xss9ipqflk4ngs78k")))
             "third_party/torch-xpu-ops")
            ;; SYCL-TLA, templates for matrix kernels such as flash
            ;; attention, at the tag of cmake/SYCLTLA.cmake of
            ;; torch-xpu-ops, which the build would fetch.
            (copy-recursively
             #$(origin
                 (method git-fetch)
                 (uri (git-reference
                       (url "https://github.com/intel/sycl-tla")
                       (commit "v0.6")))
                 (file-name "sycl-tla-for-pytorch")
                 (sha256
                  (base32
                   "132pji4w33i8nkyx0b48ijilgm2rs9n7qc21wixawq15gbmmasj8")))
             "third_party/sycl-tla")))))
    (arguments
     (substitute-keyword-arguments (package-arguments python-pytorch)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'use-torch-xpu-ops
              (lambda _
                ;; The build reads the commit of torch-xpu-ops from
                ;; third_party/xpu.txt, which the snippet of python-pytorch
                ;; deletes, and clones and checks it out with Git.  The
                ;; snippet here provides it; skip the steps with Git.
                (substitute* "caffe2/CMakeLists.txt"
                  ((".*third_party/xpu\\.txt.*") "")
                  (("if\\(NOT EXISTS .*/\\.git\"\\)") "if(FALSE)")
                  (("COMMAND git (fetch|checkout) --quiet.*")
                   "COMMAND true\n"))))
            (add-after 'use-torch-xpu-ops 'use-sycl-tla
              (lambda _
                ;; torch-xpu-ops fetches SYCL-TLA with FetchContent; point
                ;; it to the copy of the snippet.
                (substitute* "third_party/torch-xpu-ops/cmake/SYCLTLA.cmake"
                  (("^ *FetchContent_Declare\\(" all)
                   (string-append
                    "  set(FETCHCONTENT_SOURCE_DIR_REPO-SYCL-TLA"
                    " ${TORCH_ROOT}/third_party/sycl-tla)\n" all)))))
            (add-after 'use-sycl-tla 'use-dpcpp
              (lambda _
                ;; The build looks for icx and icpx, the compilers of the
                ;; oneAPI toolkit; DPC++ has clang and clang++ instead.
                (substitute* "cmake/Modules/FindSYCLToolkit.cmake"
                  (("NAMES icx") "NAMES clang++"))
                (with-directory-excursion "third_party/torch-xpu-ops/cmake"
                  (substitute* '("Modules/FindSYCL.cmake"
                                 "Modules/FindSYCLToolkit.cmake")
                    (("set\\(SYCL_EXECUTABLE_NAME icpx\\)")
                     "set(SYCL_EXECUTABLE_NAME clang++)"))
                  (substitute* "SYCL.cmake"
                    (("COMMAND icpx --version")
                     "COMMAND clang++ --version")))
                ;; The build parses the product version from the output of
                ;; icx --version, which clang++ does not print; take the
                ;; version of the SYCL implementation from sycl/version.hpp
                ;; instead, a date that serves the same comparisons.
                (substitute* "cmake/Modules/FindSYCLToolkit.cmake"
                  (("^ +parse_sycl_compiler_version\\(.*")
                   (string-append
                    "  file(STRINGS \"${SYCL_ROOT}/include/sycl/version.hpp\""
                    " _version REGEX \"define __SYCL_COMPILER_VERSION\")\n"
                    "  string(REGEX MATCH \"[0-9]+\" SYCL_COMPILER_VERSION"
                    " \"${_version}\")\n")))
                (with-directory-excursion "third_party/torch-xpu-ops/cmake"
                  ;; Only the compilers of oneAPI define this macro; check
                  ;; for SYCL as such instead.
                  (substitute* "Modules/FindSYCLToolkit.cmake"
                    (("\"__INTEL_LLVM_COMPILER\"\\)")
                     "\"SYCL_LANGUAGE_VERSION\")")
                    (("\"\\$\\{__INTEL_LLVM_COMPILER\\}\" \"\"")
                     "\"${SYCL_LANGUAGE_VERSION}\" \"\""))
                  ;; icpx flushes denormals to zero unless told otherwise;
                  ;; Clang keeps them by default and lacks the option.
                  (substitute* "BuildFlags.cmake"
                    ((".*-no-ftz\\).*") "")))))
            (add-after 'use-dpcpp 'find-libraries
              (lambda* (#:key inputs #:allow-other-keys)
                ;; The build looks for libOpenCL next to the SYCL runtime,
                ;; where the oneAPI toolkit has it; DPC++ has none.
                (substitute* "cmake/Modules/FindSYCLToolkit.cmake"
                  (("HINTS \\$\\{SYCL_LIBRARY_DIR\\}" all)
                   (string-append
                    all " "
                    (dirname (search-input-file inputs "lib/libOpenCL.so")))))
                ;; Since oneCCL 2022, libccl.so is the C API; the C++ API
                ;; of oneapi/ccl.hpp, which PyTorch uses, is libccl.so.1.
                (substitute*
                    "third_party/torch-xpu-ops/cmake/Modules/FindXCCL.cmake"
                  (("NAMES ccl") "NAMES libccl.so.1"))
                ;; oneDNN with SYCL serves both the CPU and the GPU, instead
                ;; of a second, static oneDNN that the build would fetch.
                (substitute* "aten/src/ATen/CMakeLists.txt"
                  (("ATen_XPU_DEPENDENCY_LIBS xpu_mkldnn")
                   "ATen_XPU_DEPENDENCY_LIBS DNNL::dnnl"))))
            (add-after 'find-libraries 'provide-ocloc
              (lambda _
                ;; The SYCL-TLA kernels for flash attention are compiled
                ;; ahead of time with ocloc, which intel-compute-runtime
                ;; installs with its version in the name; put an ocloc on
                ;; PATH.
                (let ((bin (string-append (dirname (getcwd)) "/ocloc-bin")))
                  (mkdir-p bin)
                  (symlink (car (find-files
                                 #$(file-append
                                    (this-package-native-input
                                     "intel-compute-runtime")
                                    "/bin")
                                 "^ocloc-"))
                           (string-append bin "/ocloc"))
                  (setenv "PATH" (string-append bin ":" (getenv "PATH"))))))
            (add-after 'provide-ocloc 'define-c99-complex
              (lambda _
                ;; The configure test of libstdc++ for the C99 functions of
                ;; complex.h fails in Guix: the libstdc++ headers on
                ;; CPLUS_INCLUDE_PATH hide those of glibc.  Without them,
                ;; c10 computes complex square roots in libc10, which
                ;; kernels cannot call; define what the test would have
                ;; found, for the host code and for the kernels.
                (setenv "CXXFLAGS" "-D_GLIBCXX11_USE_C99_COMPLEX=1")
                (substitute*
                    "third_party/torch-xpu-ops/cmake/BuildFlags.cmake"
                  (("set\\(SYCL_COMPILE_FLAGS \\$\\{SYCL_FLAGS\\}" all)
                   (string-append all " -D_GLIBCXX11_USE_C99_COMPLEX=1")))))
            (add-after 'define-c99-complex 'configure-xpu
              (lambda _
                ;; setup.py takes these from the environment.
                (setenv "USE_XPU" "1")
                (setenv "SYCL_ROOT" #$(this-package-native-input "dpcpp"))
                ;; Kernels compiled at run time for any Intel GPU, instead
                ;; of ahead of time with ocloc for a list of GPUs.
                (setenv "TORCH_XPU_ARCH_LIST" "none")
                ;; oneMKL is nonfree.
                (setenv "USE_ONEMKL_XPU" "0")
                ;; The process group xccl for distributed training.
                (setenv "USE_XCCL" "1")
                (setenv "CCL_ROOT" #$(this-package-input "oneccl"))))))))
    (native-inputs
     (modify-inputs (package-native-inputs python-pytorch)
       (prepend dpcpp intel-compute-runtime)))
    (inputs
     (modify-inputs (package-inputs python-pytorch)
       (delete "onednn")
       (prepend oneccl onednn-sycl opencl-icd-loader)))
    ;; As in dpcpp: let the Level Zero and OpenCL loaders of the SYCL
    ;; runtime find the drivers, such as intel-compute-runtime, when both
    ;; are in the same profile.
    (native-search-paths
     (append (package-native-search-paths level-zero/driver-path)
             (package-native-search-paths opencl-icd-loader)))
    (synopsis "Tensors and dynamic neural networks in Python, for Intel GPUs")
    (description
     "PyTorch is a Python package that provides two high-level features:
@itemize
@item tensor computation (like NumPy) with strong GPU acceleration;
@item deep neural networks (DNNs) built on a tape-based autograd system.
@end itemize
This variant runs on Intel GPUs through SYCL, as the device @code{xpu}.  It
is built with DPC++ and with oneDNN for SYCL.")))
