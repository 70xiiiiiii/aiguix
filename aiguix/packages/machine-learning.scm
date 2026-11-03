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
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system cargo)
  #:use-module (guix build-system copy)
  #:use-module (guix build-system pyproject)
  #:use-module (gnu packages check)
  #:use-module (gnu packages python-build)
  #:use-module ((gnu packages python-web)
                #:select (python-fastapi
                          python-openai
                          python-starlette
                          python-uvicorn))
  #:use-module (gnu packages python-xyz)
  #:use-module ((gnu packages machine-learning) #:prefix guix:)
  #:use-module (aiguix packages python-web))

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

(define-public python-transformers
  (package
    (inherit guix:python-transformers)
    (version "5.15.1")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "transformers" version))
       (sha256
        (base32 "1xw2libx4zsxvgh7g97w3dhmz90yr3yhsngq80nwipbmj2yrdj97"))))
    (arguments
     ;; Missing inputs.
     (list #:test-flags
           '(list "--ignore=tests/test_modeling_tf_common.py"
                  "--ignore=tests/test_modeling_common.py"  ; ImportError
                  "--ignore=tests/test_processing_common.py"  ; ImportError
                  "--ignore=tests/test_configuration_common.py"
                  "--ignore=tests/test_pipeline_mixin.py"
                  "--ignore=tests/test_sequence_feature_extraction_common.py"
                  "--ignore=tests/test_tokenization_mistral_common.py"
                  ;; Relative imports, only usable from the full test suite.
                  "--ignore=tests/test_tokenization_common.py"
                  ;; Imports a CI helper that is not in the release.
                  "--ignore=tests/test_image_processing_common.py"
                  ;; Requires python-accelerate
                  "--ignore=tests/test_training_args.py"
                  ;; Requires network access
                  "--ignore=tests/test_executorch.py")))
    (propagated-inputs
     (list python-fastapi               ;the CLI needs the "serving" extras
           python-huggingface-hub
           python-numpy
           python-openai
           python-packaging
           python-pydantic
           guix:python-pytorch
           python-pyyaml
           python-regex
           python-rich
           python-safetensors
           python-starlette
           guix:python-tokenizers
           python-tqdm
           python-typer
           python-uvicorn))
    (native-inputs
     (list python-parameterized
           python-pytest
           python-pytest-asyncio
           python-setuptools
           guix:python-torchvision))))

(define-public safetensors-h
  (let ((commit "13c3e315bb99c3c631c56f1540cb810ba81cd461")
        (revision "0"))
    (package
      (name "safetensors-h")
      (version (git-version "0" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/hsnyder/safetensors.h")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "1ay0dvb1c7ah3b53glqvri6w06ndsr7gaxkh4dnvkg3214mf5dkc"))))
      (build-system copy-build-system)
      (arguments
       (list
        #:install-plan
        #~'(("safetensors.h" "include/")
            ("LICENSE" "share/doc/safetensors-h/"))))
      (home-page "https://github.com/hsnyder/safetensors.h")
      (synopsis "Single-header C library to read safetensors files")
      (description
       "This is a public domain single-header C library for reading
.safetensors files, which are sometimes used to store machine learning
models.")
      (license license:unlicense))))
