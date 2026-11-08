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
;;; System services for the NPU of Intel CPUs.
;;;
;;; Code:

(define-module (aiguix services npu)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services configuration)
  #:use-module (gnu system accounts)
  #:use-module (gnu system shadow)
  #:use-module (srfi srfi-1)
  #:export (npu-configuration
            npu-configuration?
            npu-configuration-group
            npu-configuration-mode
            npu-service-type))

(define-configuration/no-serialization npu-configuration
  (group
   (string "video")
   "The group that owns the devices under @file{/dev/accel}.  The service
creates it unless @code{%base-groups} has it.")
  (mode
   (string "0666")
   "The permissions of the devices.  The default, like that of the render
nodes of GPUs, lets every user run compute on the NPU.  With @code{\"0660\"},
only the members of @code{group} can."))

(define (npu-udev-rules config)
  ;; eudev has no rule for the devices of the subsystem accel, the NPU
  ;; among them, and leaves them to root; give them to the group and mode
  ;; of CONFIG.  Like 90-kvm.rules of Guix, the rule comes late, so that
  ;; it wins over rules for accel that packages may bring.
  (list (udev-rule "90-accel.rules"
                   (string-append "SUBSYSTEM==\"accel\", GROUP=\""
                                  (npu-configuration-group config)
                                  "\", MODE=\""
                                  (npu-configuration-mode config)
                                  "\"\n"))))

(define (npu-groups config)
  ;; The default group, "video", is in %base-groups; add the group only
  ;; if it is not there.
  (let ((group (npu-configuration-group config)))
    (if (member group (map user-group-name %base-groups))
        '()
        (list (user-group (name group) (system? #t))))))

(define npu-service-type
  (service-type
   (name 'npu)
   (extensions
    (list (service-extension udev-service-type npu-udev-rules)
          (service-extension account-service-type npu-groups)))
   (default-value (npu-configuration))
   (description
    "Give users access to the NPU of Intel CPUs and other compute
accelerators under @file{/dev/accel}, which eudev otherwise leaves to
root.")))
