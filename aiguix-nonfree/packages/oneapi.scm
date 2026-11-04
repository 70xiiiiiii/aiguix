;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2026 Goran Vukoman <g@odyss3us.net>
;;;
;;; This file is not part of GNU Guix.
;;;
;;; This program is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

(define-module (aiguix-nonfree packages oneapi)
  #:use-module (aiguix packages oneapi)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module ((aiguix-nonfree licenses) #:prefix license:)
  #:use-module (guix packages))

(define-public npu-compiler-nonfree
  (package
    (inherit npu-compiler)
    (name "npu-compiler-nonfree")
    (source
     (origin
       (inherit (package-source npu-compiler))
       ;; The prebuilt and nonfree SHAVE kernels are in Git LFS.
       (method git-fetch/lfs)
       (file-name (git-file-name name (package-version npu-compiler)))
       (sha256
        (base32 "1f45ihv6525rw04m6n3csl7312ylkbaf03vhiqwzrn8ikvv4yvjl"))
       (snippet #f)))
    (synopsis "Compiler for the NPU of Intel CPUs, with SHAVE kernels")
    (description
     "This package provides the compiler that translates OpenVINO models
into programs for the NPU, the AI accelerator of Intel Core Ultra CPUs.  The
NPU driver @code{linux-npu-driver} and the NPU plugin of OpenVINO use it.

Unlike @code{npu-compiler}, it includes the prebuilt SHAVE kernels, which run
on the vector cores of the NPU.  With them, models can use operations such as
Softmax that the matrix units cannot compute.  The kernels are nonfree:
neither their source code nor the toolchain that builds them is public.")
    (license
     (list license:asl2.0
           (license:nonfree
            (string-append "https://github.com/openvinotoolkit/npu_compiler"
                           "/tree/develop/sw_runtime_kernels"))))))
