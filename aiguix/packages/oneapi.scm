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
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cpp)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages oneapi)
  #:use-module (gnu packages opencl)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages profiling)
  #:use-module (gnu packages protobuf)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages serialization)
  #:use-module (gnu packages video)
  #:use-module (gnu packages web)
  #:use-module (gnu packages xml))

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
              ;; The NPU plugin needs a user-space driver missing in Guix.
              "-DENABLE_INTEL_NPU=OFF"
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
                  level-zero
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
    (supported-systems '("x86_64-linux"))
    (home-page "https://docs.openvino.ai/")
    (synopsis "Toolkit for optimizing and deploying AI inference")
    (description
     "OpenVINO is a toolkit for optimizing and deploying deep learning models.
It converts models from frameworks such as TensorFlow, TensorFlow Lite and
PyTorch into its own intermediate representation and runs them on CPUs and
Intel GPUs.")
    ;; OpenVINO and oneDNN are under the Apache 2.0 license, MLAS under Expat.
    (license (list license:asl2.0 license:expat))))

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
optimizing and deploying deep learning models on CPUs and Intel GPUs.")
    (license license:asl2.0)))
