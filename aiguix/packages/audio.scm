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
;;; Packages that would belong to (gnu packages audio) in Guix.
;;;
;;; Code:

(define-module (aiguix packages audio)
  #:use-module (guix build-system copy)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

(define-public dr-libs
  ;; Each library is versioned separately; there is no common release.
  (let ((commit "a466dbe88fe2576d46c43877d602f3d66b8561a7")
        (revision "0"))
    (package
      (name "dr-libs")
      (version (git-version "0.0.0" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/mackron/dr_libs")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "13xxk6dxpkmmgi6bsjriq79v6b17h1r0c9865z3fv81ydhj3wxrp"))))
      (build-system copy-build-system)
      (arguments
       (list
        #:install-plan
        #~'(("dr_flac.h" "include/")
            ("dr_mp3.h" "include/")
            ("dr_wav.h" "include/"))
        #:phases
        #~(modify-phases %standard-phases
            (add-before 'install 'check
              ;; The upstream tests need an audio device and test files
              ;; that are not in the repository; make sure that each
              ;; header compiles with its implementation instead.
              (lambda* (#:key tests? #:allow-other-keys)
                (when tests?
                  (for-each (lambda (lib)
                              (let ((macro (string-append (string-upcase lib)
                                                          "_IMPLEMENTATION")))
                                (invoke "gcc"
                                        "-c"
                                        "-Wall"
                                        "-Werror"
                                        "-x"
                                        "c"
                                        (string-append "-D" macro)
                                        (string-append lib ".h")
                                        "-o"
                                        "/dev/null")
                                (invoke "g++"
                                        "-c"
                                        "-Wall"
                                        "-Werror"
                                        "-x"
                                        "c++"
                                        (string-append "-D" macro)
                                        (string-append lib ".h")
                                        "-o"
                                        "/dev/null")))
                            '("dr_flac" "dr_mp3" "dr_wav"))))))))
      (home-page "https://github.com/mackron/dr_libs")
      (synopsis "Single-file audio decoding libraries")
      (description
       "This package provides single-file C libraries for audio: dr_flac
decodes FLAC, dr_mp3 decodes MP3, and dr_wav reads and writes WAV files.
Each library is a single header file that also contains the implementation,
which is compiled into a program by defining a macro before including it.")
      (license (list license:unlicense license:expat-0)))))
