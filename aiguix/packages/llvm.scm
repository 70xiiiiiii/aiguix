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
;;; Packages that would belong to (gnu packages llvm) in Guix.
;;;
;;; Code:

(define-module (aiguix packages llvm)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages datastructures)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages mpi)
  #:use-module ((gnu packages oneapi)
                #:hide (intel-compute-runtime vc-intrinsics))
  #:use-module (gnu packages opencl)
  #:use-module (gnu packages vulkan)
  #:use-module (aiguix packages datastructures)
  #:use-module ((aiguix packages oneapi)
                #:select (intel-compute-runtime
                          level-zero/driver-path
                          vc-intrinsics)))

;; Like make-llvm-rocm in Guix: the fork builds LLVM, Clang and the SYCL
;; projects in one CMake run.
(define-public dpcpp
  (package
    (inherit llvm-23)
    (name "dpcpp")
    (version "7.2.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/intel/llvm")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1pdl2962hdb7y4s22qhi9lsv0hyax04si9j4hn69x3x79djagcq9"))
       (modules '((guix build utils)))
       ;; The build reads the SYCL projects from this source, not from the
       ;; build directory, so they are adjusted here.
       (snippet
        #~(begin
            ;; emhash installs its headers under emhash/.
            (substitute* (list "sycl/source/detail/unordered_multimap.hpp"
                               "sycl/source/detail/device_kernel_info.hpp"
                               "xptifw/include/xpti_string_table.hpp"
                               "xptifw/src/xpti_trace_framework.cpp")
              (("<(hash_table[0-9]\\.hpp)>" _ header)
               (string-append "<emhash/" header ">")))
            ;; The static UMF of Guix uses hwloc, but its CMake targets do
            ;; not say so.
            (substitute* "unified-runtime/source/common/CMakeLists.txt"
              (("set_target_properties\\(umf::umf PROPERTIES \
IMPORTED_GLOBAL TRUE\\)" all)
               (string-append all "\n  set_property(TARGET umf::umf "
                              "APPEND PROPERTY INTERFACE_LINK_LIBRARIES "
                              "hwloc)")))))))
    (arguments
     (substitute-keyword-arguments arguments
       ((#:configure-flags flags #~'())
        #~(append
           (let ((source #$(package-source this-package))
                 (gcc (assoc-ref %build-inputs "gcc"))
                 (libc (assoc-ref %build-inputs "libc")))
             (list
              ;; As in clang-from-llvm of Guix: the Clang driver finds
              ;; libgcc and the C headers of the toolchain.
              "-DUSE_DEPRECATED_GCC_INSTALL_PREFIX=ON"
              (string-append "-DGCC_INSTALL_PREFIX="
                             (ungexp
                              (@@ (gnu packages commencement) gcc-final)
                              "lib"))
              (string-append "-DC_INCLUDE_DIRS=" libc "/include")
              (string-append "-DLLVM_ENABLE_PROJECTS=clang;sycl;llvm-spirv;"
                             "opencl;xpti;xptifw;libdevice;sycl-jit")
              (string-append "-DLLVM_EXTERNAL_PROJECTS=sycl;llvm-spirv;"
                             "opencl;xpti;xptifw;libdevice;sycl-jit")
              ;; Absolute paths, as in buildbot/configure.py: xptifw
              ;; appends relative paths to XPTI_SOURCE_DIR.
              (string-append "-DLLVM_EXTERNAL_SYCL_SOURCE_DIR="
                             source "/sycl")
              (string-append "-DLLVM_EXTERNAL_LLVM_SPIRV_SOURCE_DIR="
                             source "/llvm-spirv")
              (string-append "-DLLVM_EXTERNAL_XPTI_SOURCE_DIR="
                             source "/xpti")
              (string-append "-DXPTI_SOURCE_DIR=" source "/xpti")
              (string-append "-DLLVM_EXTERNAL_XPTIFW_SOURCE_DIR="
                             source "/xptifw")
              (string-append "-DLLVM_EXTERNAL_LIBDEVICE_SOURCE_DIR="
                             source "/libdevice")
              (string-append "-DLLVM_EXTERNAL_SYCL_JIT_SOURCE_DIR="
                             source "/sycl-jit")
              ;; libdevice is compiled with the Clang of this build, which
              ;; does not find the C++ headers of GCC and glibc in Guix.
              (string-append "-DSYCL_LIBDEVICE_CXX_FLAGS="
                             "-isystem " gcc "/include/c++"
                             " -isystem " gcc
                             "/include/c++/x86_64-unknown-linux-gnu"
                             " -isystem " libc "/include")
              ;; The build takes the version from the date of the last commit
              ;; and, without .git, from the build date; this is the date of
              ;; the release commit.  Libraries compare it to enable features.
              "-DSYCL_COMPILER_VERSION=20261014"
              "-DLLVM_TARGETS_TO_BUILD=X86;SPIRV"
              ;; The SYCL runtime skips the first Level Zero adapter on
              ;; recent GPUs, so build the second one as well.
              "-DSYCL_ENABLE_BACKENDS=opencl;level_zero;level_zero_v2"
              ;; The offload tools compress device images with zstd; the
              ;; SYCL runtime must be able to decompress them.
              "-DLLVM_ENABLE_ZSTD=ON"
              "-DLLVM_INCLUDE_TESTS=OFF"
              "-DSYCL_INCLUDE_TESTS=OFF"
              "-DXPTI_ENABLE_TESTS=OFF"
              ;; Sources that the build would otherwise fetch.
              (string-append "-DFETCHCONTENT_SOURCE_DIR_VC-INTRINSICS="
                             #$(package-source vc-intrinsics))
              ;; The commit in llvm-spirv/spirv-headers-tag.conf, which is in
              ;; no release of SPIRV-Headers; later releases rename the
              ;; split barrier from INTEL to EXT.
              (string-append
               "-DLLVM_EXTERNAL_SPIRV_HEADERS_SOURCE_DIR="
               #$(origin
                   (method git-fetch)
                   (uri (git-reference
                         (url "https://github.com/KhronosGroup/SPIRV-Headers")
                         (commit "5c50cbd25a40f8b60e44a2ccc2f1ba3c9e0d0299")))
                   (sha256
                    (base32
                     "141kidgrij39j5psmgpsm2yl86rz0whp1mra60m5wkbh60aaffr6"))
                   (file-name "spirv-headers-for-dpcpp")))))
           #$flags
           ;; After the flags of LLVM, so that these win: the combined
           ;; libLLVM forms a dependency cycle with the static libraries
           ;; of SYCL.
           (list "-DLLVM_BUILD_LLVM_DYLIB=OFF"
                 "-DLLVM_LINK_LLVM_DYLIB=OFF")))
       ((#:tests? _ #f) #f)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'change-directory 'set-glibc-file-names
              (lambda* (#:key inputs #:allow-other-keys)
                ;; The parts of clang-18.0-libc-search-path.patch of Guix
                ;; that make the driver find glibc and libstdc++; the patch
                ;; itself does not apply to this fork.
                (let ((libc (assoc-ref inputs "libc"))
                      (gcc (assoc-ref inputs "gcc")))
                  (substitute* "../clang/lib/Driver/ToolChains/Linux.cpp"
                    ;; The dynamic linker of glibc.
                    (("(^[[:blank:]]+LibDir = ).*" _ declaration)
                     (string-append declaration "\"" libc "/lib\";\n"))
                    (("LibStdCXXIncludePathCandidates\\[\\] = \\{")
                     (string-append "LibStdCXXIncludePathCandidates[] = { \""
                                    gcc "/include/c++\","))
                    ;; crt1.o and friends, and libstdc++.so.
                    (("^  Generic_GCC::AddMultiarchPaths\\(D, SysRoot, \
OSLibDir, Paths\\);" all)
                     (string-append
                      all "\n  addPathIfExists(D, \"" libc "/lib\", Paths);"
                      "\n  addPathIfExists(D, "
                      "GCCInstallation.getParentLibPath(), Paths);"))))))
            (add-after 'configure 'make-copied-headers-writable
              (lambda _
                ;; The SYCL build copies OpenCL headers from the store into
                ;; include/CL, then writes its own headers there.
                (when (file-exists? "include")
                  (for-each make-file-writable
                            (find-files "include" #:directories? #t)))))
            (add-after 'configure 'create-libdevice-directory
              (lambda _
                ;; libdevice writes there without creating it.
                (mkdir-p (string-append
                          "lib/dpcpp-"
                          #$(version-major (package-version this-package))
                          "/sycl"))))))))
    (native-inputs
     (modify-inputs native-inputs
       (append parallel-hashmap)))
    (inputs
     (modify-inputs inputs
       (append emhash
               `(,hwloc "lib")
               intel-compute-runtime    ;Level Zero headers of Intel GPUs
               level-zero/driver-path
               opencl-icd-loader
               umf
               `(,zstd "lib"))))
    ;; The SYCL headers include CL/cl.h.
    (propagated-inputs (list opencl-headers))
    ;; The include and library paths of Clang, and let the Level Zero and
    ;; OpenCL loaders find the drivers, such as intel-compute-runtime, when
    ;; both are in the same profile.
    (native-search-paths
     (append (package-native-search-paths clang-23)
             (package-native-search-paths level-zero/driver-path)
             (package-native-search-paths opencl-icd-loader)))
    ;; Not the release monitoring URL of LLVM: the updater follows the tags
    ;; of the repository.
    (properties '())
    (home-page "https://github.com/intel/llvm")
    (synopsis "SYCL compiler for Intel GPUs")
    (description
     "DPC++ is the LLVM-based compiler of Intel for SYCL, a C++ standard for
programming accelerators such as GPUs in single-source C++.  It provides the
@command{clang++} driver with @option{-fsycl}, and the SYCL runtime, which
runs kernels on Intel GPUs through Level Zero or OpenCL.")
    (license license:asl2.0)))   ;with LLVM exceptions

(define-public dpcpp-toolchain
  (package
    (inherit (make-clang-toolchain dpcpp libomp-23))
    (home-page "https://github.com/intel/llvm")
    (synopsis "Complete DPC++ toolchain for SYCL development")
    (description
     "This package provides a complete DPC++ toolchain for SYCL, C and C++
development to be installed in user profiles.  This includes DPC++, as well
as libc (headers and binaries, plus debugging symbols in the @code{debug}
output), and Binutils.  Use it instead of @code{gcc-toolchain}, whose C++
headers may not match the GCC that DPC++ uses.")))
