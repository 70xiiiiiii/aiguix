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
;;; Packages that would belong to (gnu packages version-control) in Guix.
;;;
;;; Code:

(define-module (aiguix packages version-control)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (gnu packages)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages version-control))

;; OpenVINO Model Server pins this commit and adds Git LFS support to it,
;; which it needs to download model weights from Hugging Face.
(define-public libgit2-for-ovms
  (let ((commit "1f34e2a57a3d03f174771203b64aed2b17e8522c")
        (revision "0"))
    (package
      (inherit libgit2-1.9)
      (name "libgit2-for-ovms")
      (version (git-version "1.9.0" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/libgit2/libgit2")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "0lgdcz3x4a8c0l2zh7623xk0m2lqxnhwfbrvjjy8zwnwwc0pd2pi"))
         (patches
          (cons (origin
                  (method url-fetch)
                  (uri (string-append
                        "https://raw.githubusercontent.com/openvinotoolkit/"
                        "model_server/v2026.4.1/third_party/libgit2/"
                        "lfs.patch"))
                  (file-name "libgit2-for-ovms-lfs.patch")
                  (sha256
                   (base32
                    "0g6ansl2jqvv0ky20i3w8w7bwmch2qgwkznq9id41mjsywl1jp4z")))
                (search-patches "libgit2-proxy-reconnection.patch")))
         (modules '((guix build utils)))
         (snippet
          #~(for-each delete-file-recursively
                      '("deps/llhttp" "deps/ntlmclient" "deps/pcre"
                        "deps/winhttp" "deps/zlib")))))
      (arguments
       (substitute-keyword-arguments (package-arguments libgit2-1.9)
         ;; The LFS patch removes the test suite from the build.
         ((#:tests? _ #f)
          #f)
         ((#:configure-flags flags)
          ;; As in OVMS; the LFS filter uses the SHA256 object IDs.
          #~(cons* "-DEXPERIMENTAL_SHA256=ON" "-DBUILD_CLI=OFF"
                   "-DBUILD_TESTS=OFF"
                   #$flags))))
      (inputs (modify-inputs (package-inputs libgit2-1.9)
                (prepend curl)))
      (synopsis "Library providing Git core methods, with Git LFS support"))))
