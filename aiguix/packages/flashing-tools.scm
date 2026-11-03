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
;;; Packages that would belong to (gnu packages flashing-tools) in Guix.
;;;
;;; Code:

(define-module (aiguix packages flashing-tools)
  #:use-module (guix build-system cmake)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

(define-public metee
  (package
    (name "metee")
    (version "6.2.6")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/intel/metee")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "18ixsaf7vn10adr0s4gmsrhdk1zvaiw35jji7nz0w3q20zxxq5d0"))))
    (build-system cmake-build-system)
    (arguments
     (list
      ;; The tests talk to a real device through /dev/mei0 and download
      ;; googletest at configure time.
      #:tests? #f
      #:configure-flags
      #~(list "-DBUILD_SHARED_LIBS=ON")))
    (home-page "https://github.com/intel/metee")
    (synopsis "Library to access Intel CSME and GSC firmware interfaces")
    (description
     "MeTee is a C library to communicate with the firmware of Intel's
Converged Security and Management Engine (CSME) and of the Graphics System
Controller (GSC) of Intel discrete GPUs through the Linux @code{mei} driver.
It provides a C and a C++ interface.")
    (license license:asl2.0)))
