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
;;; Packages that would belong to (gnu packages web) in Guix.
;;;
;;; Code:

(define-module (aiguix packages web)
  #:use-module (guix build-system cmake)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages dns)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages serialization)
  #:use-module (gnu packages tls))

;; OpenVINO Model Server pins this commit and changes Drogon and its bundled
;; Trantor (third_party/drogon/ovms_drogon_trantor.patch in its sources).
(define-public drogon-for-ovms
  (let ((commit "686f68a12ff82c6c3114a4c48502334261f258f6")
        (revision "0"))
    (package
      (name "drogon-for-ovms")
      (version (git-version "1.9.9" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/drogonframework/drogon")
               (commit commit)
               ;; Trantor is a submodule; OVMS patches it as well.
               (recursive? #t)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "0ka88x4n22shgvm4nxpk03xlwg3hwvzi5mh1nlzb3hm9h0wmi9f1"))
         (modules '((guix build utils)
                    (ice-9 string-fun)
                    (ice-9 textual-ports)))
         (snippet
          #~(let ((replace-once
                   (lambda (file old new)
                     (let* ((text (call-with-input-file file get-string-all))
                            (start (string-contains text old)))
                       (unless (and start
                                    (not (string-contains text old
                                                          (+ start 1))))
                         (error "text not found exactly once in" file old))
                       (make-file-writable file)
                       (call-with-output-file file
                         (lambda (port)
                           (put-string port (string-replace-substring
                                             text old new))))))))
              ;; OVMS sends the header of a streamed response itself, once
              ;; it knows the status, through ResponseStream::sendHeader().
              (substitute* "lib/inc/drogon/HttpResponse.h"
                (("\\(trantor::AsyncStreamPtr asyncStream\\)")
                 "(trantor::AsyncStreamPtr asyncStream,
                            trantor::TcpConnectionPtr tcpConnection)")
                ((": asyncStream_\\(std::move\\(asyncStream\\)\\)" all)
                 (string-append all ",
          tcpConnection_(std::move(tcpConnection))"))
                (("^    bool send\\(const std::string &data\\)" all)
                 (string-append "    void sendHeader(const std::string &data)
    {
        tcpConnection_->send(data);
    }

" all))
                (("^    trantor::AsyncStreamPtr asyncStream_;" all)
                 (string-append all "
    trantor::TcpConnectionPtr tcpConnection_;"))
                (("^    /// Return the string of http version of request" all)
                 (string-append
                  "    virtual std::string renderHeaderToString() = 0;\n\n"
                  all)))
              (substitute* "lib/src/HttpResponseImpl.h"
                (("^    void addHeader\\(const char \\*start," all)
                 (string-append
                  "    std::string renderHeaderToString() override;\n\n"
                  all)))
              (substitute* "lib/src/HttpResponseImpl.cc"
                (("^using namespace std::literals::string_literals;" all)
                 (string-append all "

std::string HttpResponseImpl::renderHeaderToString()
{
    auto msg = this->renderToBuffer();
    return std::string(msg->peek(), msg->readableBytes());
}")))
              ;; Stream also if the client sent "Connection: close", as
              ;; editor plugins such as Continue do, and send the header of
              ;; other responses at once, as before.
              (replace-once "lib/src/HttpServer.cc"
                "        auto httpString = respImplPtr->renderToBuffer();
        conn->send(httpString);
        if (!respImplPtr->contentLengthIsAllowed())
            return;
        auto &asyncStreamCallback = respImplPtr->asyncStreamCallback();
        if (asyncStreamCallback)
        {
            if (!respImplPtr->ifCloseConnection())
            {
                asyncStreamCallback(
                    std::make_unique<ResponseStream>(conn->sendAsyncStream(
                        respImplPtr->asyncStreamKickoffDisabled())));
            }
            else
            {
                LOG_INFO << \"Chunking Set CloseConnection !!!\";
            }
        }
"
                "        if (!respImplPtr->contentLengthIsAllowed())
            return;
        auto &asyncStreamCallback = respImplPtr->asyncStreamCallback();
        if (asyncStreamCallback)
        {
            asyncStreamCallback(std::make_unique<ResponseStream>(
                conn->sendAsyncStream(
                    respImplPtr->asyncStreamKickoffDisabled()),
                conn));
        }
        else
        {
            auto httpString = respImplPtr->renderToBuffer();
            conn->send(httpString);
        }
")
              ;; The same in sendResponses(), the only remaining place.
              (substitute* "lib/src/HttpServer.cc"
                (("if \\(!respImplPtr->ifCloseConnection\\(\\)\\)")
                 "if (true)")
                (("respImplPtr->asyncStreamKickoffDisabled\\(\\)\\)\\)\\);")
                 "respImplPtr->asyncStreamKickoffDisabled()),
                            conn));"))
              ;; Keep repeated multipart fields such as "name[]".
              (substitute* "lib/inc/drogon/MultiPart.h"
                (("&getParameters\\(\\) const;" all)
                 (string-append all "
    const SafeStringMap<std::vector<std::string>> &getParametersVector()
        const;"))
                (("^    SafeStringMap<std::string> parameters_;" all)
                 (string-append all "
    SafeStringMap<std::vector<std::string>> parametersVector_;")))
              (substitute* "lib/src/MultiPart.cc"
                (("^int MultiPartParser::parse\\(.*&req\\)\n" all)
                 (string-append
                  "const SafeStringMap<std::vector<std::string>> &
MultiPartParser::getParametersVector() const
{
    return parametersVector_;
}

" all))
                (("parameters_\\.emplace\\(name, std::string\\(headEnd.*;")
                 "std::string value(headEnd + 2, end);
                parameters_.emplace(name, value);
                parametersVector_[name].push_back(std::move(value));"))
              ;; Do not create 256 upload cache directories at start-up.
              (substitute* "lib/src/HttpAppFrameworkImpl.cc"
                (("utils::createPath\\(.*dirName\\);")
                 "(void)dirName;"))
              (substitute* "lib/src/Utilities.cc"
                (("^#include <iomanip>\n") "")
                (("^#include <drogon/config.h>" all)
                 (string-append all "\n#include <iomanip>"))
                (("LOG_ERROR << \"deflateInit2 error!\";" all)
                 (string-append all
                                "\n            (void)deflateEnd(&strm);")))
              ;; Trantor: report errors instead of exiting, and always write
              ;; directly so that streamed and unary responses keep their
              ;; order.
              (substitute* "trantor/trantor/net/TcpConnection.h"
                (("^    void setSSLErrorCallback\\(const" all)
                 (string-append "    CloseCallback getCloseCallback() const
    {
        return closeCallback_;
    }

" all)))
              (substitute* "trantor/trantor/net/EventLoop.cc"
                (("std::cout << \"Failed in eventfd\" << std::endl;")
                 "std::cout << \"Failed in eventfd: \" << strerror(errno)
                  << \" (errno: \" << errno << \")\" << std::endl;
        if (errno == EMFILE || errno == ENFILE)
            std::cout << \"try reducing the number of rest_workers or \"
                         \"increase open files limit\"
                      << std::endl;"))
              (substitute* "trantor/trantor/net/inner/Socket.cc"
                (("^using namespace trantor;" all)
                 (string-append "#include <stdexcept>\n\n" all)))
              (replace-once "trantor/trantor/net/inner/Socket.cc"
                "toIpPort();
        exit(1);"
                "toIpPort();
        throw std::runtime_error(\"bind address failed\");")
              (replace-once "trantor/trantor/net/inner/Socket.cc"
                "\"listen failed\";
        exit(1);"
                "\"listen failed\";
        throw std::runtime_error(\"listen failed\");")
              (substitute* "trantor/trantor/net/inner/TcpConnectionImpl.cc"
                (("LOG_SYSERR << \"no writing but write callback called\";")
                 "LOG_WARN << \"write callback but not writing, fd=\"
                 << socketPtr_->fd()
                 << \" status=\" << static_cast<int>(status_)
                 << \" writeBufferList.size=\" << writeBufferList_.size()
                 << \" tlsProvider=\"
                 << (tlsProviderPtr_ ? \"yes\" : \"no\");")
                (("^    if \\(!ioChannelPtr_->isWriting\\(\\) && w.*")
                 "    // Always write directly.\n"))))))
      (build-system cmake-build-system)
      (arguments
       (list
        ;; The same features as in OVMS; the ORM needs database clients.
        #:configure-flags
        #~(list "-DBUILD_SHARED_LIBS=ON"
                "-DBUILD_CTL=OFF"
                "-DBUILD_EXAMPLES=OFF"
                "-DBUILD_ORM=OFF"
                "-DBUILD_BROTLI=OFF"
                "-DBUILD_YAML_CONFIG=OFF"
                "-DBUILD_TESTING=ON")
        #:phases
        #~(modify-phases %standard-phases
            (add-before 'check 'copy-test-certificates
              ;; The CookieSameSite test needs the certificate that is only
              ;; copied for the integration tests, which need drogon_ctl.
              (lambda _
                (for-each (lambda (file)
                            (copy-file
                             (string-append "../source/trantor/trantor/tests/"
                                            file)
                             (string-append "lib/tests/" file)))
                          '("server.crt" "server.key")))))))
      ;; Required by the installed CMake configuration.
      (propagated-inputs
       (list c-ares jsoncpp openssl (list util-linux "lib") zlib))
      (home-page "https://github.com/drogonframework/drogon")
      (synopsis "C++ HTTP framework, as used by OpenVINO Model Server")
      (description
       "Drogon is an HTTP(S) web application framework for C++ based on the
non-blocking network library Trantor.  This version carries the changes that
OpenVINO Model Server needs, for example to send the response header of a
streamed response itself.")
      (license license:expat))))
