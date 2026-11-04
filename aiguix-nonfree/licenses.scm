;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2026 Goran Vukoman <g@odyss3us.net>
;;;
;;; This file is not part of GNU Guix.
;;;
;;; This program is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <http://www.gnu.org/licenses/>.


(define-module (aiguix-nonfree licenses)
  #:export (nonfree))

(define license (@@ (guix licenses) license))

(define* (nonfree uri #:optional (comment ""))
  "Return a nonfree license, whose full text can be found at URI, which may
be a file:// URI pointing to the package's tree."
  (license "Nonfree" uri
           (string-append
            "This is a nonfree license.  Check the URI for details.  "
            comment)))
