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
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages spice)
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

(define-public xlibre-input-joystick
  (package
    (name "xlibre-input-joystick")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-input-joystick")
             (commit (string-append "xlibre-xf86-input-joystick-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0rnwr6rg4swv2cannw9j6rj32nf1a069bqvwi7rm842vm59l27iw"))))
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
    (home-page "https://github.com/X11Libre/xf86-input-joystick")
    (synopsis "Joystick input driver for XLibre")
    (description
     "This package provides a joystick input driver for the XLibre X
server.  It is used to control the pointer with a joystick device.")
    (license license:x11)))

(define-public xlibre-input-keyboard
  (package
    (name "xlibre-input-keyboard")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-input-keyboard")
             (commit (string-append "xlibre-xf86-input-keyboard-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0f9avrf5nq0x901m0zij5idkhg2y50nj60065bdjhv1msnlgpwbk"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules"))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-input-keyboard")
    (synopsis "Keyboard input driver for XLibre")
    (description
     "This package provides a keyboard input driver for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-input-libinput
  (package
    (name "xlibre-input-libinput")
    (version "25.0.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-input-libinput")
             (commit (string-append "xlibre-xf86-input-libinput-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1q2k7l69ig39h4snmbvpxp1c2y32k5h3qqwzcqlnq2hckyx6fakl"))))
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
    (inputs (list libinput-minimal xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-input-libinput")
    (synopsis "Input driver for XLibre based on libinput")
    (description
     "This package provides an input driver for the XLibre X server based on
libinput.  It is a thin wrapper around libinput, so it provides all features
that libinput supports and does little beyond.")
    (license (list license:x11 ;install-sh
                   license:expat))))

(define-public xlibre-input-mouse
  (package
    (name "xlibre-input-mouse")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-input-mouse")
             (commit (string-append "xlibre-xf86-input-mouse-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "19iy13yl1fahh8mj219srkrzy0a40ssdikkjx07x7v8dx3qrdjpk"))))
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
    (home-page "https://github.com/X11Libre/xf86-input-mouse")
    (synopsis "Mouse input driver for XLibre")
    (description
     "This package provides a mouse input driver for the XLibre X server.  It
supports serial, bus and PS/2 mice, and mouse types supported by specific
operating systems, such as USB mice.")
    (license license:x11)))

(define-public xlibre-input-synaptics
  (package
    (name "xlibre-input-synaptics")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-input-synaptics")
             (commit (string-append "xlibre-xf86-input-synaptics-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "00zasb9g4n7vs4drvw3aprfdzrjxkhdl3mgkds6l70hdydmhjm4r"))))
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
    (inputs (list libevdev libx11 libxi mtdev xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-input-synaptics")
    (synopsis "Touchpad input driver for XLibre")
    (description
     "This package provides a touchpad input driver for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-input-vmmouse
  (package
    (name "xlibre-input-vmmouse")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-input-vmmouse")
             (commit (string-append "xlibre-xf86-input-vmmouse-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0jrlvqr5dhpxjdgl09cyik86spg533p09s54484dd0m48zr30ij1"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              (string-append "--with-xorg-conf-dir="
                             #$output "/share/X11/xorg.conf.d"))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list eudev xlibre-server))
    (supported-systems (filter (lambda (system)
                                 (or (string-prefix? "i686-" system)
                                     (string-prefix? "x86_64-" system)))
                               %supported-systems))
    (home-page "https://github.com/X11Libre/xf86-input-vmmouse")
    (synopsis "VMware mouse input driver for XLibre")
    (description
     "This package provides an input driver for the VMware virtual mouse for
the XLibre X server.")
    (license license:x11)))

(define-public xlibre-input-void
  (package
    (name "xlibre-input-void")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-input-void")
             (commit (string-append "xlibre-xf86-input-void-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1h4fcval1vx9vaj15fjl4nn1zdx5x9ic0dr0y96y5gnrdkc92cxf"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules"))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-input-void")
    (synopsis "Void (null) input driver for XLibre")
    (description
     "This package provides a null input driver for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-input-wacom
  (package
    (name "xlibre-input-wacom")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-input-wacom")
             (commit (string-append "xlibre-xf86-input-wacom-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0k4zwvnwf19ly83x2kvn3fjb8mzf9zk4j93p1rmv5qv66vk27428"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              (string-append "--with-sdkdir="
                             #$output "/include/xorg")
              (string-append "--with-xorg-conf-dir="
                             #$output "/share/X11/xorg.conf.d"))
      #:phases
      #~(modify-phases %standard-phases
          (replace 'bootstrap
            (lambda _
              ;; autogen.sh runs configure unconditionally.
              (invoke "autoreconf" "-vfi"))))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list eudev
                  libx11
                  libxi
                  libxinerama
                  libxrandr
                  xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-input-wacom")
    (synopsis "Wacom tablet input driver for XLibre")
    (description
     "This package provides an input driver for Wacom tablets for the XLibre X
server.")
    (license license:gpl2+)))

(define-public xlibre-video-amdgpu
  (package
    (name "xlibre-video-amdgpu")
    (version "25.1.2")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-amdgpu")
             (commit (string-append "xlibre-xf86-video-amdgpu-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1gxanj05miim1mrdplrpf6kbicsjyf839hzjl1clamcpsq0bypgz"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'configure 'set-install-directories
            (lambda _
              ;; xlibre-server.pc points into the server's store item.
              (setenv "PKG_CONFIG_XLIBRE_SERVER_VIDEO_DRIVERS_DIR"
                      (string-append #$output "/lib/xorg/modules/drivers"))
              (setenv "PKG_CONFIG_XLIBRE_SERVER_DRIVER_MAN_DIR"
                      (string-append #$output "/share/man/man4"))
              (setenv "PKG_CONFIG_XORG_SERVER_SYSCONFIGDIR"
                      (string-append #$output "/share/X11/xorg.conf.d")))))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list eudev mesa xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-amdgpu")
    (synopsis "AMD Radeon video driver for XLibre")
    (description
     "This package provides a video driver for AMD Radeon graphics cards
supported by the amdgpu kernel driver, for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-apm
  (package
    (name "xlibre-video-apm")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-apm")
             (commit (string-append "xlibre-xf86-video-apm-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1w96f6xbzvdbyynk921j530y7x88g0slf7g193pj857vqs7a5r4i"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")
      #:phases
      #~(modify-phases %standard-phases
          (replace 'bootstrap
            (lambda _
              ;; autogen.sh runs configure unconditionally.
              (invoke "autoreconf" "-vfi"))))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-apm")
    (synopsis "Alliance ProMotion video driver for XLibre")
    (description
     "This package provides a video driver for Alliance ProMotion graphics
chips for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-ark
  (package
    (name "xlibre-video-ark")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-ark")
             (commit (string-append "xlibre-xf86-video-ark-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1q12p1vi3wlqysg7r7afsbjlvqgkbxkz6cs5zsz7bf7rgk8kzf2i"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")
      #:phases
      #~(modify-phases %standard-phases
          (replace 'bootstrap
            (lambda _
              ;; autogen.sh runs configure unconditionally.
              (invoke "autoreconf" "-vfi"))))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-ark")
    (synopsis "Ark Logic video driver for XLibre")
    (description
     "This package provides a video driver for Ark Logic graphics chips for
the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-ast
  (package
    (name "xlibre-video-ast")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-ast")
             (commit (string-append "xlibre-xf86-video-ast-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0crgz1lqrqcv78kx1psd62yzc16hjg4ajx2199q91ba65ghr80bc"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-ast")
    (synopsis "ASpeed Technologies video driver for XLibre")
    (description
     "This package provides a video driver for ASpeed Technologies graphics
chips for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-ati
  (package
    (name "xlibre-video-ati")
    (version "25.0.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-ati")
             (commit (string-append "xlibre-xf86-video-ati-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "04nybnikr3xkc6fwgiwh95y8xb89z7bnynyssim5x4zz37zg679x"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              (string-append "--with-xorg-conf-dir="
                             #$output "/share/X11/xorg.conf.d")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list eudev mesa xlibre-server xorgproto))
    (home-page "https://github.com/X11Libre/xf86-video-ati")
    (synopsis "ATI Radeon video driver for XLibre")
    (description
     "This package provides a video driver for ATI Radeon graphics cards
supported by the radeon kernel driver, for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-chips
  (package
    (name "xlibre-video-chips")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-chips")
             (commit (string-append "xlibre-xf86-video-chips-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0d1aakb1qq93w10aa8zip4z2imbgww5mw0jryr0c4if67w3zmwpm"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-chips")
    (synopsis "Chips and Technologies video driver for XLibre")
    (description
     "This package provides a video driver for Chips and Technologies graphics
chips for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-cirrus
  (package
    (name "xlibre-video-cirrus")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-cirrus")
             (commit (string-append "xlibre-xf86-video-cirrus-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0hxs6kdx899f20v5zsiqdcl8f2m136jwfqbb3zkbi75ap95vx3jf"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-cirrus")
    (synopsis "Cirrus Logic video driver for XLibre")
    (description
     "This package provides a video driver for Cirrus Logic graphics chips for
the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-dummy
  (package
    (name "xlibre-video-dummy")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-dummy")
             (commit (string-append "xlibre-xf86-video-dummy-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "02d612hrljdiyi577718lgyvvb90jph2pi4rvxb7hwfzghialdf7"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules"))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-dummy")
    (synopsis "Dummy video driver for XLibre")
    (description
     "This package provides a virtual, off-screen frame buffer driver for the
XLibre X server, for example for remote sessions with xpra.")
    (license license:x11)))

(define-public xlibre-video-fbdev
  (package
    (name "xlibre-video-fbdev")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-fbdev")
             (commit (string-append "xlibre-xf86-video-fbdev-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0qafmg0a28sa822xhncg1f5x2w9ya55jix3yyrf3897c820z5z3g"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-fbdev")
    (synopsis "Framebuffer device video driver for XLibre")
    (description
     "This package provides a video driver for the Linux framebuffer device
for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-geode
  (package
    (name "xlibre-video-geode")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-geode")
             (commit (string-append "xlibre-xf86-video-geode-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1vmp624qp51lvyby0mbih2fa7llqrw5x4s5z2mxrzllvydy833m3"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules"))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (supported-systems (filter (lambda (system)
                                 (string-prefix? "i686-" system))
                               %supported-systems))
    (home-page "https://github.com/X11Libre/xf86-video-geode")
    (synopsis "AMD Geode GX/LX video driver for XLibre")
    (description
     "This package provides a video driver for the AMD Geode GX and LX
processors for the XLibre X server.  It supports EXA acceleration, Xv overlay
and dynamic rotation with XRandR.")
    (license license:x11)))

(define-public xlibre-video-i128
  (package
    (name "xlibre-video-i128")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-i128")
             (commit (string-append "xlibre-xf86-video-i128-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "19563k236f401qpp20ckvxnys3qdys3903vnxfjdjwqlbyf0za7j"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")
      #:phases
      #~(modify-phases %standard-phases
          (replace 'bootstrap
            (lambda _
              ;; autogen.sh runs configure unconditionally.
              (invoke "autoreconf" "-vfi"))))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-i128")
    (synopsis "Number Nine Imagine 128 video driver for XLibre")
    (description
     "This package provides a video driver for Number Nine Imagine 128
graphics cards for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-i740
  (package
    (name "xlibre-video-i740")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-i740")
             (commit (string-append "xlibre-xf86-video-i740-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1ldn2qd4a5bp9s417imsggdk1n0r5sfhhyahh8psfamd0k3sc1dp"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (supported-systems (filter (lambda (system)
                                 (or (string-prefix? "i686-" system)
                                     (string-prefix? "x86_64-" system)))
                               %supported-systems))
    (home-page "https://github.com/X11Libre/xf86-video-i740")
    (synopsis "Intel i740 video driver for XLibre")
    (description
     "This package provides a video driver for Intel i740 graphics chips for
the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-intel
  (package
    (name "xlibre-video-intel")
    (version "25.0.2")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-intel")
             (commit (string-append "xlibre-xf86-video-intel-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0b8llgwl9w4j13qcwyj6zp0i2wdwzzsbrw57fzvmn55ms0l3ixf0"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules"))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list eudev libx11 libxfont2 mesa xlibre-server))
    (supported-systems (filter (lambda (system)
                                 (or (string-prefix? "i686-" system)
                                     (string-prefix? "x86_64-" system)))
                               %supported-systems))
    (home-page "https://github.com/X11Libre/xf86-video-intel")
    (synopsis "Intel video driver for XLibre")
    (description
     "This package provides a 2D video driver for Intel graphics chips for the
XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-mach64
  (package
    (name "xlibre-video-mach64")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-mach64")
             (commit (string-append "xlibre-xf86-video-mach64-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1fbsaalqjpyz99faiy5gvysph0b1b3mb3ardnm20vxw4air99w7l"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list mesa xlibre-server xorgproto))
    (home-page "https://github.com/X11Libre/xf86-video-mach64")
    (synopsis "ATI Mach64 video driver for XLibre")
    (description
     "This package provides a video driver for ATI graphics cards based on the
Mach64 series or older chips for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-mga
  (package
    (name "xlibre-video-mga")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-mga")
             (commit (string-append "xlibre-xf86-video-mga-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0i2ixi7ly2vj0jwmva82kvr8vncy73ws1rc4qbs62myf22axi1zg"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules"))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list mesa xlibre-server xorgproto))
    (home-page "https://github.com/X11Libre/xf86-video-mga")
    (synopsis "Matrox video driver for XLibre")
    (description
     "This package provides a video driver for Matrox graphics cards for the
XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-neomagic
  (package
    (name "xlibre-video-neomagic")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-neomagic")
             (commit (string-append "xlibre-xf86-video-neomagic-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "04wfa1rx9w4r6gq58kr6gl2vh9bg8ysr50l06za53j2plqb89qb2"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules"))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server xorgproto))
    (home-page "https://github.com/X11Libre/xf86-video-neomagic")
    (synopsis "NeoMagic video driver for XLibre")
    (description
     "This package provides a video driver for NeoMagic graphics chips for the
XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-nested
  (package
    (name "xlibre-video-nested")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-nested")
             (commit (string-append "xlibre-xf86-video-nested-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1j3qnpw3inwbdgkgqb19d3rkmai3r6fvwix0bblgqpms871siy8q"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules"))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list libx11 libxext xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-nested")
    (synopsis "Nested video driver for XLibre")
    (description
     "This package provides a video driver that runs the XLibre X server
inside a window of another X server.")
    (license license:x11)))

(define-public xlibre-video-nouveau
  (package
    (name "xlibre-video-nouveau")
    (version "25.0.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-nouveau")
             (commit (string-append "xlibre-xf86-video-nouveau-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1n10pwfdf2b7in2qhk7xk6padd2mikf0blxhjr9gswm1v95c1sah"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list eudev xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-nouveau")
    (synopsis "NVIDIA video driver for XLibre")
    (description
     "This package provides a video driver for NVIDIA graphics cards supported
by the nouveau kernel driver, for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-nv
  (package
    (name "xlibre-video-nv")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-nv")
             (commit (string-append "xlibre-xf86-video-nv-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0ylija24r92jv4sjy9ldrllwrlzymq8z43ral7mdilff95x5cqq3"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-nv")
    (synopsis "Legacy NVIDIA video driver for XLibre")
    (description
     "This package provides a 2D video driver for older NVIDIA graphics cards
for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-qxl
  (package
    (name "xlibre-video-qxl")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-qxl")
             (commit (string-append "xlibre-xf86-video-qxl-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "07axgwbqddlj9qvaq8raqzcr3acg7djs8y6s09cm5lsjx0wscyh8"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")
      #:phases
      #~(modify-phases %standard-phases
          (replace 'bootstrap
            (lambda _
              ;; autogen.sh runs configure unconditionally.
              (invoke "autoreconf" "-vfi"))))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list libxfont2 spice-protocol xlibre-server xorgproto))
    (home-page "https://github.com/X11Libre/xf86-video-qxl")
    (synopsis "QXL video driver for XLibre")
    (description
     "This package provides a video driver for the SPICE QXL virtual graphics
device for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-r128
  (package
    (name "xlibre-video-r128")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-r128")
             (commit (string-append "xlibre-xf86-video-r128-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0zi7csrzwnx1aqmm7zi8v4kx65p8xdizl2vzaf0gfxnfrmvxz1ab"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list mesa xlibre-server xorgproto))
    (home-page "https://github.com/X11Libre/xf86-video-r128")
    (synopsis "ATI Rage 128 video driver for XLibre")
    (description
     "This package provides a video driver for ATI Rage 128 graphics cards for
the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-rendition
  (package
    (name "xlibre-video-rendition")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-rendition")
             (commit (string-append "xlibre-xf86-video-rendition-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1m3akzqqzbx0jb6ppxsa8wd41f7v7dln4wwhha7f89ra8g28z5bh"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-rendition")
    (synopsis "Rendition video driver for XLibre")
    (description
     "This package provides a video driver for Rendition Verite graphics chips
for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-s3virge
  (package
    (name "xlibre-video-s3virge")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-s3virge")
             (commit (string-append "xlibre-xf86-video-s3virge-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1jnkbbc3zsys8pddj63c4bklcl7i5wbjgar2gp38yv0f4pd4as20"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-s3virge")
    (synopsis "S3 ViRGE video driver for XLibre")
    (description
     "This package provides a video driver for S3 ViRGE graphics chips for the
XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-savage
  (package
    (name "xlibre-video-savage")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-savage")
             (commit (string-append "xlibre-xf86-video-savage-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "05dphm9s01fi366r79hhqcjzbql4gh2m4n36lc0d1n4wpyxqx2bj"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list mesa xlibre-server xorgproto))
    (home-page "https://github.com/X11Libre/xf86-video-savage")
    (synopsis "S3 Savage video driver for XLibre")
    (description
     "This package provides a video driver for S3 Savage graphics chips for
the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-siliconmotion
  (package
    (name "xlibre-video-siliconmotion")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-siliconmotion")
             (commit (string-append "xlibre-xf86-video-siliconmotion-"
                                    version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1kw5yas828mwn3pqbz5s7b9kccv0z6iz0s5qr24qrbhrqa56b4dz"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-siliconmotion")
    (synopsis "Silicon Motion video driver for XLibre")
    (description
     "This package provides a video driver for Silicon Motion graphics chips
for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-sis
  (package
    (name "xlibre-video-sis")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-sis")
             (commit (string-append "xlibre-xf86-video-sis-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "12npq9jyxxyncybnpd86wn7af9hggjq781a9ssbmfnl3p19djqqm"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list mesa xlibre-server xorgproto))
    (home-page "https://github.com/X11Libre/xf86-video-sis")
    (synopsis "SiS video driver for XLibre")
    (description
     "This package provides a video driver for SiS graphics chips of the
300/315/330/340 series for the XLibre X server.")
    (license license:bsd-3)))

(define-public xlibre-video-sisusb
  (package
    (name "xlibre-video-sisusb")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-sisusb")
             (commit (string-append "xlibre-xf86-video-sisusb-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0svdqkjq77a5rklid94x2p5hhp0mqp54k80hlgk6xz7chx4pyf2f"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-sisusb")
    (synopsis "SiS USB video driver for XLibre")
    (description
     "This package provides a video driver for SiS USB graphics adapters for
the XLibre X server.")
    (license license:bsd-3)))

(define-public xlibre-video-tdfx
  (package
    (name "xlibre-video-tdfx")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-tdfx")
             (commit (string-append "xlibre-xf86-video-tdfx-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0c7lnw084lrnm4q531q3494bjllm0y28g09bdl3n4nhqq7ny6y1q"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules"))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list mesa xlibre-server xorgproto))
    (home-page "https://github.com/X11Libre/xf86-video-tdfx")
    (synopsis "3dfx video driver for XLibre")
    (description
     "This package provides a video driver for 3dfx Voodoo3, Voodoo4 and
Voodoo5 graphics cards for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-trident
  (package
    (name "xlibre-video-trident")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-trident")
             (commit (string-append "xlibre-xf86-video-trident-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1dxfa7vqvaxpkf2sl1kw7xqspyskzqh05dfavd56nbwgbzzc45g7"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-trident")
    (synopsis "Trident video driver for XLibre")
    (description
     "This package provides a video driver for Trident graphics chips for the
XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-v4l
  (package
    (name "xlibre-video-v4l")
    (version "25.0.1")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-v4l")
             (commit (string-append "xlibre-xf86-video-v4l-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1savyxzmmaq51bbsbf48dgrv1x46vr4hw8k9n97icq9hzy2w56fs"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules"))
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'configure 'set-install-directories
            (lambda _
              ;; xlibre-server.pc points into the server's store item.
              (setenv "PKG_CONFIG_XLIBRE_SERVER_VIDEO_DRIVERS_DIR"
                      (string-append #$output "/lib/xorg/modules/drivers"))
              (setenv "PKG_CONFIG_XLIBRE_SERVER_DRIVER_MAN_DIR"
                      (string-append #$output "/share/man/man4"))
              (setenv "PKG_CONFIG_XORG_SERVER_SYSCONFIGDIR"
                      (string-append #$output "/share/X11/xorg.conf.d"))))
          (replace 'bootstrap
            (lambda _
              ;; autogen.sh runs configure unconditionally.
              (invoke "autoreconf" "-vfi"))))))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (home-page "https://github.com/X11Libre/xf86-video-v4l")
    (synopsis "Video4Linux Xv driver for XLibre")
    (description
     "This package provides an Xv driver for the XLibre X server that shows
video from Video4Linux devices, such as TV cards.")
    (license license:x11)))

(define-public xlibre-video-vbox
  (package
    (name "xlibre-video-vbox")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-vbox")
             (commit (string-append "xlibre-xf86-video-vbox-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0z38gh0c29q70nv8bgjag8pzc48l9cl5ndxs02zkq9yx0fgx4wc9"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (supported-systems (filter (lambda (system)
                                 (or (string-prefix? "i686-" system)
                                     (string-prefix? "x86_64-" system)))
                               %supported-systems))
    (home-page "https://github.com/X11Libre/xf86-video-vbox")
    (synopsis "VirtualBox video driver for XLibre")
    (description
     "This package provides a video driver for the VirtualBox virtual graphics
device for the XLibre X server.")
    (license license:x11)))

(define-public xlibre-video-vesa
  (package
    (name "xlibre-video-vesa")
    (version "25.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/X11Libre/xf86-video-vesa")
             (commit (string-append "xlibre-xf86-video-vesa-" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0x3f5db1q5pxvml787zkl0ca82aqk2zlss1b4jvyv9qcjsbwf929"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:configure-flags
      #~(list (string-append "--with-xorg-module-dir="
                             #$output "/lib/xorg/modules")
              "CFLAGS=-g -O2 -Wno-error=implicit-function-declaration")))
    (native-inputs (list autoconf automake libtool pkg-config util-macros))
    (inputs (list xlibre-server))
    (supported-systems (filter (lambda (system)
                                 (or (string-prefix? "i686-" system)
                                     (string-prefix? "x86_64-" system)))
                               %supported-systems))
    (home-page "https://github.com/X11Libre/xf86-video-vesa")
    (synopsis "VESA video driver for XLibre")
    (description
     "This package provides a generic VESA video driver for the XLibre X
server.")
    (license license:x11)))
