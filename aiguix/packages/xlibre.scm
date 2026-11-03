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
;;; XLibre (https://github.com/X11Libre) is a fork of the Xorg server.
;;; Guix's X service takes any server that installs bin/X and
;;; lib/xorg/modules, so XLibre replaces xorg-server through the `server'
;;; field of `xorg-configuration':
;;;
;;;   (xorg-configuration
;;;     (server xlibre-server)
;;;     (modules (list ...)))
;;;
;;; Not packaged:
;;;
;;;   - suncg3, suncg6, suncg14, sunffb, sunleo, suntcx: SPARC only; Guix
;;;     does not run on SPARC.
;;;   - freedreno, omap: ARM only; not yet built and tested.
;;;
;;; Code:

(define-module (aiguix packages xlibre)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system meson)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages xorg))

(define-public xlibre-server
  (package
    (name "xlibre-server")
    (version "25.2.3")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xserver")
             (commit (string-append "xlibre-xserver-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1kyr3zk9zz9j1vrhip7crsw1k6xyr2lghybcjnsnwf33j9n7g2yw"))))
    (build-system meson-build-system)
    (propagated-inputs
     ;; Required by xorg-server.pc, which the drivers build against.
     (list libpciaccess
           libxcvt
           libxfont2
           mesa
           pixman
           xorgproto))
    (inputs (list dbus
                  eudev
                  libdmx
                  libdrm
                  libepoxy
                  libgcrypt
                  libxau
                  libxaw
                  libxdmcp
                  libxfixes
                  libxkbfile
                  libxrender
                  libxres
                  libxshmfence
                  libxt
                  libxv
                  xkbcomp
                  xkeyboard-config
                  xtrans
                  zlib
                  ;; For Xephyr.
                  xcb-util
                  xcb-util-image
                  xcb-util-keysyms
                  xcb-util-renderutil
                  xcb-util-wm))
    (native-inputs (list pkg-config
                         python-wrapper
                         ;; For the tests.
                         xdpyinfo
                         xrandr
                         xvinfo))
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "-Dxkb_dir="
                             #$(this-package-input "xkeyboard-config")
                             "/share/X11/xkb")
              (string-append "-Dxkb_bin_dir="
                             #$(this-package-input "xkbcomp") "/bin")
              ;; Compiled keymaps are written at run time; the store is
              ;; read-only.  Same choice as Guix's xorg-server.
              "-Dxkb_output_dir=/tmp"
              ;; Otherwise it ends up as '${prefix}/...', which fails with
              ;; "_FontTransOpen: Unable to Parse address".  It is not used.
              "-Ddefault_font_path="
              ;; The X security extension, for ssh -X.
              "-Dxcsecurity=true"
              ;; For the log file.
              "-Dlocalstatedir=/var"
              "-Dglamor=true"
              "-Dxephyr=true" ;for SDDM
              "-Dxnest=true"
              "-Dxvfb=true"
              ;; elogind provides the logind D-Bus interface.
              "-Dsystemd_logind=true"
              "-Dsystemd_notify=false")
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'configure 'patch-bin-sh
            (lambda _
              (substitute* (find-files "." "\\.c$")
                (("/bin/sh")
                 (which "sh"))))))))
    (home-page "https://github.com/X11Libre/xserver")
    (synopsis "XLibre X server, a fork of the Xorg server")
    (description
     "This package provides the XLibre X server, a fork of the Xorg X server
with code cleanups and new features.  It is a drop-in replacement for
@code{xorg-server}: the X server accepts requests from client programs to
create windows, which are composed on the screen as directed by the window
manager.")
    (license license:x11)))

(define-public xlibre-input-elographics
  (package
    (name "xlibre-input-elographics")
    (version "25.0.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-input-elographics")
             (commit (string-append "xlibre-xf86-input-elographics-"
                                    version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1wdibgm534g4brfsivyd4x8pqivyfapqvi2dc9n444mv4ynpmf81"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              (string-append "--with-sdkdir="
                             #$output "/include/xorg"))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-input-elographics")
    (synopsis "Elographics touchscreen input driver for XLibre")
    (description
     "This package provides an input driver for Elographics touchscreens for
the XLibre X server.")
    (license license:x11)))

(define-public xlibre-input-evdev
  (package
    (name "xlibre-input-evdev")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-input-evdev")
             (commit (string-append "xlibre-xf86-input-evdev-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1hcac307kx9agj2c64k62zhhs9bz84qfj8pzybxnyqmbdvcpdrsr"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              (string-append "--with-sdkdir="
                             #$output "/include/xorg")
              (string-append "--with-xorg-conf-dir="
                             #$output "/share/X11/xorg.conf.d"))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list eudev libevdev mtdev xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-input-evdev")
    (synopsis "Generic input driver for XLibre")
    (description
     "This package provides a generic input driver for the XLibre X
server.  It supports all input devices that the kernel knows about, including
most mice, keyboards, tablets and touchscreens.")
    (license license:x11)))
