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
  #:use-module (ice-9 match)
  #:use-module (aiguix packages oneapi)
  #:use-module (gnu packages compression)
  #:use-module (guix base32)
  #:use-module (guix build-system copy)
  #:use-module (guix download)
  #:use-module (guix gexp)
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

(define-public onemkl
  (package
    (name "onemkl")
    (version "2026.2.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://files.pythonhosted.org/packages/dc/51/"
             "3447e212ae3b09f3da7f0ae1b834aa452b8114cfffbb7a8f702715cb3706/"
             "mkl-" version "-py2.py3-none-manylinux_2_28_x86_64.whl"))
       (sha256
        (base32 "1mqfa11l7g5x8y4g5wl1az06ixxs0vpjqqymcqyaniwzrrsiiaza"))))
    (build-system copy-build-system)
    (arguments
     (list
      ;; The license forbids modifying the libraries, so they are neither
      ;; stripped nor given a RUNPATH.  They find libsycl, libtbb and each
      ;; other when the program that links them has loaded these.
      #:strip-binaries? #f
      #:validate-runpath? #f
      #:phases
      #~(modify-phases %standard-phases
          (replace 'unpack
            (lambda* (#:key inputs #:allow-other-keys)
              ;; The source and the other wheels.
              (for-each (lambda (wheel)
                          (invoke "unzip" "-q" wheel))
                        (filter (lambda (file)
                                  (string-suffix? ".whl" file))
                                (map cdr inputs)))))
          (replace 'install
            (lambda _
              ;; Each wheel keeps the files of the prefix, such as lib/
              ;; and include/, in NAME-VERSION.data/data; merge them all
              ;; into the output.
              (for-each (lambda (data)
                          (copy-recursively data #$output))
                        (find-files "."
                                    (lambda (file stat)
                                      (string-suffix? ".data/data" file))
                                    #:directories? #t))
              ;; The license asks to reproduce its terms.
              (install-file (string-append "mkl-"
                                           #$(package-version this-package)
                                           ".dist-info/LICENSE.txt")
                            (string-append #$output "/share/doc/mkl"))
              ;; The names to link with, which the wheels of the oneAPI
              ;; toolkit leave out.
              (with-directory-excursion (string-append #$output "/lib")
                (for-each (lambda (library)
                            (let ((name (basename library)))
                              (symlink name
                                       (string-append
                                        (substring
                                         name 0 (string-contains name ".so."))
                                        ".so"))))
                          (find-files "." "\\.so\\.[0-9]+$"))))))))
    (native-inputs
     (cons
      unzip
      (map                              ;each wheel: name, directory, hash
       (match-lambda
         ((name directory hash)
          (origin
            (method url-fetch)
            (uri (string-append "https://files.pythonhosted.org/packages/"
                                directory "/" name "-"
                                (package-version this-package)
                                "-py2.py3-none-manylinux_2_28_x86_64.whl"))
            (sha256 (nix-base32-string->bytevector hash)))))
       '(("mkl_include"
          "79/76/92504b3f0e1caa52c5dd1422a5f0ddac111b6339ccd2a3a87a657900553c"
          "08j8xkxh7bjdb1lnv2y0g2x25lp0qhpyp2ws3vp1yrx1awhcg748")
         ("onemkl_sycl_include"
          "29/85/56513df991f9ba59a1c5e9046a279371f764ccae78fd8144d45d844b8c35"
          "0yj53q3bsd095xfrk03xd2822n23w52wrqn7r7q6vka1gjnbpglp")
         ("onemkl_sycl_blas"
          "7f/d9/e18a72511338885b2a2a9345adfdaf527f8b3587687e1dd3ec1c41881956"
          "11wkjjvxxa9mh8cfivjjb48zsh0zzvbmf3acvl5h1y2jyq3zvcnl")
         ("onemkl_sycl_dft"
          "c8/37/4f16ceff75a3163fbed298ecd8d4a8ea16217f99f819cad1cc7fa1ca9f90"
          "0fnhc6zyz4hgax8zr37rx8gnris3za66lchvwd0n2bixgw67ddic")
         ("onemkl_sycl_lapack"
          "dc/b4/ba5c7dfa03c3370b59de66a16dd45e112db401f57a7c304708be80aa5a86"
          "00w87f8fa48qdc2lq19i3rilv3zldjz4swzib19n0frn9z9g4x3z")
         ("onemkl_sycl_rng"
          "30/a0/47fe81b9b4313c899caecde1bae36f46ca78f88c02b73d1d7f3338acf168"
          "1fnmn58h8c4ah83vny6n5icw61zhdkp38x2g79ri00k2p969bq4h")
         ("onemkl_sycl_sparse"
          "5e/4c/ea7fc29ac0e94bf7a7c903802af2ad0e073795c03789334e732ef26a74db"
          "1fxrjpghz295m7h2gmyh5adpd1vbihx94lmg43rrahi1dgaw6wdl")))))
    ;; The name of the main wheel on PyPI.
    (properties '((upstream-name . "mkl")))
    (home-page
     (string-append "https://www.intel.com/content/www/us/en/developer"
                    "/tools/oneapi/onemkl.html"))
    (synopsis "Math Kernel Library of Intel, for CPUs and SYCL GPUs")
    (description
     "The @acronym{oneMKL, oneAPI Math Kernel Library} provides BLAS,
LAPACK, FFT, vector math and random number routines optimized for Intel CPUs,
and their SYCL versions for Intel GPUs: BLAS, LAPACK, DFT, random numbers and
sparse BLAS.  The SYCL libraries link with the SYCL runtime of DPC++.

oneMKL is nonfree: Intel distributes it in binary form only, under a license
that forbids modifying it.  This package takes the binaries from the Python
wheels of Intel unmodified.")
    (license
     (license:nonfree "file://mkl-2026.2.0.dist-info/LICENSE.txt"))))
