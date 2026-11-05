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
  #:use-module (gnu packages mpi)
  #:use-module ((gnu packages oneapi) #:select (onednn umf))
  #:use-module (gnu packages opencl)
  #:use-module (gnu packages parallel)
  #:use-module (gnu packages profiling)
  #:use-module ((aiguix packages oneapi) #:select (level-zero/driver-path))
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
      ;; The tests need a SYCL device and the reference BLAS of Netlib.
      #:tests? #f
      #:configure-flags
      #~(list "-DCMAKE_C_COMPILER=clang"
              "-DCMAKE_CXX_COMPILER=clang++"
              ;; The oneMKL backends are nonfree; use the generic SYCL
              ;; backends instead, which run on any SYCL device.
              "-DENABLE_MKLCPU_BACKEND=OFF"
              "-DENABLE_MKLGPU_BACKEND=OFF"
              "-DENABLE_GENERIC_BLAS_BACKEND=ON"
              ;; No portFFT backend for DFT: portFFT uses the sub-group load
              ;; and store of SYCL, which DPC++ 7 removed.
              "-DBUILD_FUNCTIONAL_TESTS=OFF"
              "-DBUILD_EXAMPLES=OFF"
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
       ;; Binaries of Intel MPI and libfabric, and copies of hwloc, ITT,
       ;; Level Zero, PMIx and UMF.
       (snippet
        #~(with-directory-excursion "deps/libccl/deps"
            (for-each delete-file-recursively
                      '("hwloc" "itt" "level_zero" "mpi" "ofi" "pmix"
                        "umf"))))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list "-DCMAKE_C_COMPILER=clang"
              "-DCMAKE_CXX_COMPILER=clang++"
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
              ;; The Git submodules of ITT and GoogleTest.
              (substitute* "deps/CMakeLists.txt"
                (("^ *(require_submodule|add_subdirectory)\\((ittapi\
|googletest).*") ""))
              (substitute* "tests/CMakeLists.txt"
                (("^function\\(add_test_internal\\)" all)
                 (string-append "find_package(GTest REQUIRED)\n" all))
                (("^( +)(gtest|gtest_main)\n" _ indentation target)
                 (string-append indentation "GTest::" target "\n")))
              ;; The CPU libccl.so.1 in lib/ccl/cpu/lib needs libccl.so.2
              ;; from lib.
              (substitute* "CMakeLists.txt"
                (("-l:libccl\\.so\\.2 \\$\\{STATIC_INTEL_FLAG\\}" all)
                 (string-append all " -Wl,-rpath," #$output "/lib")))
              ;; DT_RPATH lets the CPU libccl.so.1 win over one in
              ;; LD_LIBRARY_PATH; use DT_RUNPATH as everywhere in Guix.
              (substitute* "plugins/legacy_cpu/CMakeLists.txt"
                (("\"-Wl,--disable-new-dtags\"") ""))
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
                  (("libhwloc\\.a") "libhwloc.so")
                  ;; Not a copy of libfabric in the package.
                  (("if \\(\"\\$\\{LIBFABRIC_DIR\\}\" STREQUAL \"\"\\)")
                   "if(FALSE)"))
                ;; Libraries that libccl loads at run time.
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
              ;; The tests are registered for this configuration only.
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
        ;; After the flags of onednn, so that these win.
        #~(append #$flags
                  (list (string-append "-DCMAKE_C_COMPILER="
                                       #$(file-append dpcpp "/bin/clang"))
                        (string-append "-DCMAKE_CXX_COMPILER="
                                       #$(file-append dpcpp "/bin/clang++"))
                        "-DDNNL_GPU_RUNTIME=SYCL"
                        ;; The graph API, which PyTorch uses for attention
                        ;; on Intel GPUs.
                        "-DONEDNN_BUILD_GRAPH=ON")))
       ;; These need a SYCL device.
       ((#:test-exclude _ "") "_gpu$|^test_api_sycl$")
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'fix-cache-size-without-sysfs
              (lambda _
                ;; On hybrid CPUs, the cache sizes come from /sys, which the
                ;; build environment lacks; a size of 0 makes the CPU
                ;; primitives divide by zero.  Fall back to CPUID then.
                (substitute* "src/cpu/x64/platform.cpp"
                  (("return min_cache_bytes;")
                   "return min_cache_bytes > 0 ? min_cache_bytes
        : get_per_core_cache_size_cpuid(level);"))))))))
    (native-inputs
     (modify-inputs (package-native-inputs onednn)
       (prepend dpcpp)))
    (inputs
     (modify-inputs (package-inputs onednn)
       (prepend libomp-23 opencl-icd-loader)))
    (synopsis "Deep neural network library for CPUs and SYCL GPUs")
    (description
     "@acronym{OneDNN, OneAPI Deep Neural Network Library} is a cross-platform
performance library of basic building blocks for deep learning applications.
This variant is built with DPC++ and runs on Intel GPUs through SYCL as well
as on CPUs, and includes the graph API.")))
