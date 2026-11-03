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
;;; Packages that Guix has in (gnu packages machine-learning).  Packages
;;; with the same name as in Guix are newer versions that inherit from the
;;; Guix package, which this module refers to as guix:<name>.
;;;
;;; Code:

(define-module (aiguix packages machine-learning)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system cargo)
  #:use-module (guix build-system pyproject)
  #:use-module ((gnu packages machine-learning) #:prefix guix:))

(define-public python-safetensors
  (package
    (inherit guix:python-safetensors)
    (version "0.8.0")
    (source
     (origin
       (inherit (package-source guix:python-safetensors))
       (uri (pypi-uri "safetensors" version))
       (sha256
        (base32 "0gbmkpnvmqib8dxzrkqznz17fzqmc8jnhq35ngcihrlay7hg7fps"))
       (snippet
        #~(begin
            ;; Keep the bindings, the Python sources and the Rust crate
            ;; they are built from; move the bindings to the top.
            (for-each (lambda (file)
                        (unless (member file
                                        '("." ".." "bindings" "py_src"
                                          "safetensors" "PKG-INFO"))
                          (delete-file-recursively file)))
                      (scandir "."))
            (for-each (lambda (file)
                        (unless (member file
                                        '("." ".."))
                          (rename-file (string-append "bindings/python/" file)
                                       file)))
                      (scandir "bindings/python"))
            (substitute* "Cargo.toml"
              (("\\.\\./\\.\\./safetensors")
               "safetensors"))))))
    (inputs (cargo-inputs 'python-safetensors
                          #:module '(aiguix packages rust-crates)))))
