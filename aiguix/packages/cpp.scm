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
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system copy)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (gnu packages cpp))

(define-public minitrace
  ;; No tagged releases.
  (let ((commit "679ac44bfa1f6537a08dd4638c2ae4ae8c62f556")
        (revision "0"))
    (package
      (name "minitrace")
      (version (git-version "0.0.0" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/hrydgard/minitrace")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "0h9dxcamw60jclxyd7gq311r6asxzpmn9hhw1da39dv019w5yp6q"))))
      (build-system cmake-build-system)
      (arguments
       (list
        #:configure-flags
        #~(list "-DMTR_BUILD_SHARED=ON" "-DMTR_BUILD_TEST=ON")
        #:phases
        #~(modify-phases %standard-phases
            (replace 'check
              ;; There is no test suite; run the two example programs,
              ;; which write their traces to the current directory.
              (lambda* (#:key tests? #:allow-other-keys)
                (when tests?
                  (invoke "./minitrace_test")
                  (invoke "./minitrace_test_mt")))))))
      (home-page "https://github.com/hrydgard/minitrace")
      (synopsis "Tracing library for Chrome's trace viewer")
      (description
       "Minitrace is a small C library with C++ helpers that records the
start and end of code blocks as JSON traces, which can be viewed in the
@code{chrome://tracing} viewer of Chromium-based browsers.")
      (license license:expat))))

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
