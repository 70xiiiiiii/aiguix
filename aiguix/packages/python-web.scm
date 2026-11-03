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
;;; Packages that Guix has in (gnu packages python-web).  Packages with
;;; the same name as in Guix are newer versions that inherit from the Guix
;;; package, which this module refers to as guix:<name>.
;;;
;;; Code:

(define-module (aiguix packages python-web)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (gnu packages nss)
  #:use-module (gnu packages python-xyz)
  #:use-module ((gnu packages python-web) #:prefix guix:))

(define-public python-huggingface-hub
  (package
    (inherit guix:python-huggingface-hub)
    (version "1.26.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/huggingface/huggingface_hub")
             (commit (string-append "v" version))))
       (file-name (git-file-name "python-huggingface-hub" version))
       (sha256
        (base32 "0n1pla6rfjf3pq79ab34074pcbmqinrbsk9s1zkj21xh1ssnj22c"))))
    (arguments
     (list
      #:test-flags
      ;; We don't have sentence_transformers...
      '(list (string-append "--ignore=contrib/sentence_transformers/"
                            "test_sentence_transformers.py")
             ;; ...nor do we have InquirerPy...
             "--ignore=tests/test_command_delete_cache.py"
             ;; ...or timm...
             "--ignore=contrib/timm/test_timm.py"
             ;; ...or spacy_huggingface_hub
             "--ignore=contrib/spacy/test_spacy.py"
             ;; These all require internet access
             "--ignore=tests/test_cache_no_symlinks.py"
             "--ignore=tests/test_cache_layout.py"
             "--ignore=tests/test_commit_scheduler.py"
             "--ignore=tests/test_file_download.py"
             "--ignore=tests/test_hf_api.py"
             "--ignore=tests/test_hf_file_system.py"
             "--ignore=tests/test_inference_api.py"
             "--ignore=tests/test_inference_async_client.py"
             "--ignore=tests/test_inference_client.py"
             "--ignore=tests/test_inference_text_generation.py"
             "--ignore=tests/test_login_utils.py"
             "--ignore=tests/test_offline_utils.py"
             "--ignore=tests/test_repocard.py"
             "--ignore=tests/test_repository.py"
             "--ignore=tests/test_snapshot_download.py"
             "--ignore=tests/test_utils_cache.py"
             "--ignore=tests/test_utils_git_credentials.py"
             "--ignore=tests/test_utils_http.py"
             "--ignore=tests/test_utils_pagination.py"
             "--ignore=tests/test_webhooks_server.py"
             "--ignore=tests/test_buckets.py"
             "--ignore=tests/test_buckets_cli.py"
             "--ignore=tests/test_buckets_hf_file_system.py"
             "--ignore=tests/test_cli_discussions.py"
             "--ignore=tests/test_copy_files.py"
             "--ignore=tests/test_kernels.py"
             "-k"
             (string-append "not test_push_to_hub"
              " and not test_from_pretrained_model_id_only"
              " and not test_from_pretrained_model_id_and_revision"
              ;; These all require internet access
              " and not test_auth"
              " and not test_oauth"
              " and not test_utils_sha"
              " and not test_inference_providers"
              " and not test_xet"
              " and not test_repo_list"
              " and not test_models_ls_files"
              " and not test_datasets_ls_files"
              " and not test_spaces_ls_files"
              " and not test_card_full"
              " and not test_list_hardware"
              " and not test_json_flag_produces_json_output"
              " and not test_json_flag_equivalent_to_format_json"
              " and not test_add_installs_marketplace_skill_to_dest"
              " and not test_update_checks_remote_revision"
              ;; These need DuckDB.
              " and not test_datasets_sql"))
      #:phases '(modify-phases %standard-phases
                  (add-after 'unpack 'relax-requirements
                    (lambda _
                      ;; 8.4.2 only fixes the fish completion script.
                      (substitute* "setup.py"
                        (("click>=8\\.4\\.2")
                         "click>=8.4.1"))))
                  (add-before 'check 'pre-check
                    ;; Some tests need to write to HOME.
                    (lambda _
                      (setenv "HOME" "/tmp"))))))
    (propagated-inputs (modify-inputs (package-propagated-inputs
                                       guix:python-huggingface-hub)
                         (delete "python-requests")
                         (prepend python-click guix:python-httpx)))
    (native-inputs (modify-inputs (package-native-inputs
                                   guix:python-huggingface-hub)
                     (prepend nss-certs-for-test)))))
