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
;;; Packages that would belong to (gnu packages monitoring) in Guix.
;;;
;;; Code:

(define-module (aiguix packages monitoring)
  #:use-module (guix build-system cmake)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (gnu packages check)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages web))

(define-public prometheus-cpp
  (package
    (name "prometheus-cpp")
    (version "1.3.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/jupp0r/prometheus-cpp")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0y028dmd05nh6iargxd6kqxb9pvq6il1vk0szskmlafzlzwhs3sx"))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list "-DBUILD_SHARED_LIBS=ON"
              ;; Use civetweb and googletest from Guix instead of the git
              ;; submodules.
              "-DUSE_THIRDPARTY_LIBRARIES=OFF")))
    (native-inputs (list googletest))
    ;; Required by the installed CMake configuration.
    (propagated-inputs (list civetweb curl zlib))
    (home-page "https://github.com/jupp0r/prometheus-cpp")
    (synopsis "Prometheus client library for C++")
    (description
     "This library allows C++ programs to expose metrics, such as counters,
gauges, histograms and summaries, to the Prometheus monitoring system.  The
metrics can be scraped over HTTP (pull) or sent to a Pushgateway (push).")
    (license license:expat)))
