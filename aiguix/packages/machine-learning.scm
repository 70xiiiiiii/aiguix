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
  #:use-module (gnu packages python-check)
  #:use-module ((gnu packages python-web)
                #:select (python-fastapi
                          python-openai
                          python-starlette
                          python-uvicorn))
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages tls)
  #:use-module ((gnu packages machine-learning) #:prefix guix:)
  #:use-module (aiguix packages python-web))

(define-public python-accelerate
  (package
    (name "python-accelerate")
    (version "1.15.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/huggingface/accelerate")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1760z7wm93gyxl34l5f9aa6nxygc5aa6h3g29v9p4v63j9635h4d"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:test-flags
      '(list "tests"
             ;; DeepSpeed is not packaged.
             "--ignore=tests/deepspeed"
             ;; These tests require network access.
             "--deselect=tests/test_cli.py::ModelEstimatorTester"
             ;; ProcessGroupGloo::allgather: invalid tensor size.
             "--deselect=tests/test_cpu.py::MultiCPUTester::test_cpu")))
    (propagated-inputs (list python-huggingface-hub
                             python-numpy
                             python-packaging
                             python-psutil
                             guix:python-pytorch
                             python-pyyaml
                             python-safetensors))
    (native-inputs (list openssl ;for torch.compile in the tests
                         python-parameterized
                         python-pytest
                         python-pytest-order
                         python-setuptools
                         guix:python-torchvision
                         python-transformers))
    (home-page "https://github.com/huggingface/accelerate")
    (synopsis "Run PyTorch training on any device configuration")
    (description
     "Accelerate abstracts the boilerplate code related to multi-GPU, TPU and
mixed-precision setups of PyTorch training scripts, so that the same script
runs on a CPU, a single GPU or a distributed setup.  It also provides
utilities for loading big models across devices and offloading their weights,
which libraries such as Transformers use for quantized models.")
    (license license:asl2.0)))

(define-public python-optimum
  (package
    (name "python-optimum")
    (version "2.3.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/huggingface/optimum")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "15hl3xzpsiv1dv81mdp57cra29rfwbq9ax62chc5jifahk92h4rl"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      ;; Most tests download models from the Hugging Face Hub, and
      ;; test_register_command writes into the installed package.
      #:test-flags
      #~(list "tests/common"
              "tests/cli/test_cli.py::TestCLI::test_env_commands")
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'register-commands-once
            (lambda _
              ;; The namespace of the command modules of backends can be
              ;; found both in a profile and, through the wrapper of
              ;; optimum-cli, in the store; do not register a command twice.
              (substitute* "optimum/commands/optimum_cli.py"
                (("^    commands_to_register = \\[\\]" all)
                 (string-append all "\n    loaded_modules = set()"))
                (("if register_file\\.suffix != \"\\.py\":")
                 (string-append "if (register_file.suffix != \".py\""
                                " or register_file.stem in loaded_modules):"))
                (("^( +)register_module = importlib\\.import_module.*" all
                  indent)
                 (string-append all indent
                                "loaded_modules.add("
                                "register_file.stem)\n"))))))))
    (propagated-inputs (list python-huggingface-hub python-numpy
                             python-packaging guix:python-pytorch
                             python-transformers))
    (native-inputs (list python-parameterized python-pytest
                         python-setuptools))
    (home-page "https://huggingface.co/docs/optimum")
    (synopsis "Hardware optimization extension of Hugging Face Transformers")
    (description
     "Optimum extends Hugging Face Transformers with tools to export,
quantize and optimize models for specific hardware and runtimes.  This package
provides the common base and the @command{optimum-cli} command; backends such
as OpenVINO are provided by separate packages that plug into it.")
    (license license:asl2.0)))

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
