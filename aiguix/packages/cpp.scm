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
;;; Packages that would belong to (gnu packages cpp) in Guix.
;;;
;;; Code:

(define-module (aiguix packages cpp)
  #:use-module (guix build-system copy)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (gnu packages cpp))

(define-public minja
  (let ((commit "021c2293c187789ef13d56c6cfd89c9b134fd80f")
        (revision "0"))
    (package
      (name "minja")
      (version (git-version "0" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/google/minja")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "1vywzaycqwvk1qgkkc4c83syf2ajjvpq0g02v3sk3mhha394ymdl"))))
      (build-system copy-build-system)
      (arguments
       (list
        #:install-plan
        #~'(("include/minja" "include/minja")
            ("LICENSE" "share/doc/minja/"))))
      (propagated-inputs (list nlohmann-json))
      (home-page "https://github.com/google/minja")
      (synopsis "Minimalistic Jinja template engine for LLM chat templates")
      (description
       "Minja is a minimalistic reimplementation of the Jinja templating
engine to integrate in/with C++ LLM projects.")
      (license license:expat))))
