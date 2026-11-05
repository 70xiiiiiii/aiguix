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
