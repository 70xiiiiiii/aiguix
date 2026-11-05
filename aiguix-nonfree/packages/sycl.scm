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

;;; Commentary:
;;;
;;; Nonfree variants of the packages in (aiguix packages sycl).
;;;
;;; Code:

(define-module (aiguix-nonfree packages sycl)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (aiguix-nonfree packages oneapi)
  #:use-module (aiguix packages sycl))

(define-public python-pytorch-xpu-nonfree
  (package
    (inherit python-pytorch-xpu)
    (name "python-pytorch-xpu-nonfree")
    (arguments
     (substitute-keyword-arguments (package-arguments python-pytorch-xpu)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'configure-xpu 'use-onemkl
              (lambda _
                ;; oneMKL 2026 takes strides and the workspace size as
                ;; int64_t vectors and values, and has no conjugate-even
                ;; storage setting, as in the torch-xpu-ops commits
                ;; f00322c0 and 1680b4e7.
                (substitute* (string-append "third_party/torch-xpu-ops/src/"
                                            "ATen/native/xpu/mkl/"
                                            "SpectralOps.cpp")
                  (("(_strides)\\.data\\(\\)\\);" _ name)
                   (string-append name ");"))
                  (("size_t workspaceSizeBytes") "int64_t workspaceSizeBytes")
                  ((".*CONJUGATE_EVEN_STORAGE.*") ""))
                ;; Linear algebra and FFT on the GPU, which otherwise run on
                ;; the CPU.
                (setenv "USE_ONEMKL_XPU" "1")
                (setenv "MKLROOT" #$(this-package-input "onemkl"))))))))
    (inputs
     (modify-inputs (package-inputs python-pytorch-xpu)
       (prepend onemkl)))
    (synopsis "PyTorch for Intel GPUs, with oneMKL for linear algebra")
    (description
     "PyTorch is a Python package that provides two high-level features:
@itemize
@item tensor computation (like NumPy) with strong GPU acceleration;
@item deep neural networks (DNNs) built on a tape-based autograd system.
@end itemize
This variant runs on Intel GPUs through SYCL, as the device @code{xpu}.

Unlike @code{python-pytorch-xpu}, it computes fast Fourier transforms and
much of linear algebra, such as solving and inverting, on the GPU with
oneMKL.  oneMKL is nonfree: Intel distributes it
in binary form only.")
    (license
     (list (package-license python-pytorch-xpu)
           (package-license onemkl)))))
