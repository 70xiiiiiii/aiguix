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
;;; Packages that Guix has in (gnu packages rpc).  Packages with the same
;;; name as in Guix are newer versions that inherit from the Guix package,
;;; which this module refers to as guix:<name>.
;;;
;;; Code:

(define-module (aiguix packages rpc)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (gnu packages cpp)
  #:use-module (gnu packages protobuf)
  #:use-module (gnu packages regex)
  #:use-module ((gnu packages rpc) #:prefix guix:))

;; ovms and its MediaPipe fork need a gRPC built with the same, current
;; Abseil as protobuf-6; the grpc of Guix is built with an older one.
(define-public grpc
  (package
    (inherit guix:grpc)
    (version "1.74.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/grpc/grpc")
             (commit (string-append "v" version))))
       (file-name (git-file-name "grpc" version))
       (sha256
        (base32 "0flz0irkv6jydcmvm08rxmcgf41q3ldxbqialb3isywx5aq8715z"))))
    (native-inputs (modify-inputs (package-native-inputs guix:grpc)
                     (replace "protobuf" protobuf-6)))
    (inputs (modify-inputs (package-inputs guix:grpc)
              (replace "re2" re2-next)))
    (propagated-inputs (list abseil-cpp))))
