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
;;; Packages that would belong to (gnu packages vulkan) in Guix.
;;;
;;; Code:

(define-module (aiguix packages vulkan)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages vulkan))

;; Needed by Intel Graphics Compiler 2.42.6, which requires this exact major
;; version.
(define-public spirv-llvm-translator-22
  (package
    (inherit spirv-llvm-translator)
    (version "22.1.8")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/KhronosGroup/SPIRV-LLVM-Translator")
             (commit (string-append "v" version))))
       (file-name (git-file-name "spirv-llvm-translator" version))
       (sha256
        (base32 "1xgdsn12dxx6vrncyv0ji58xm6kpa22243xrxg2gn30g6m83ll8i"))))
    (inputs
     (modify-inputs inputs
       (replace "llvm" llvm-22)))
    (native-inputs
     (modify-inputs native-inputs
       (replace "clang" clang-22)
       (replace "llvm" llvm-22)
       ;; The exact SPIRV-Headers version this package needs, as named in
       ;; spirv-headers-tag.conf.
       (replace "spirv-headers"
         (origin
           (method git-fetch)
           (uri (git-reference
                 (url "https://github.com/KhronosGroup/SPIRV-Headers")
                 (commit "cb42dec3830d3ac67fa449ecdc0c0f73d5e74498")))
           (file-name "spirv-headers-for-spirv-llvm-translator")
           (sha256
            (base32
             "1cigylzmphs8r43k6c6bcq6if9b4mjrsw6gkpdpvgrirscgvx7c5"))))))))
