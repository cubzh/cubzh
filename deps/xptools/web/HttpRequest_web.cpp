
#include "HttpRequest.hpp"
#include "WSService.hpp"

namespace vx {

void HttpRequest::_sendAsync(HttpRequest_SharedPtr httpReq) {
    HttpRequest::_requestsMutex.lock();
    HttpRequest::_requestsWaiting.push(httpReq);
    HttpRequest::_requestsMutex.unlock();
    HttpRequest::_sendNextRequest(nullptr);
}

void HttpRequest::_cancel(HttpRequest_SharedPtr httpReq) {
    //    if (this->_fetch != nullptr) {
    //        // request is flying
    //        emscripten_fetch_close(this->_fetch); // cancel request
    //    } else {
    //        // req is not flying
    //    }

    if (httpReq != nullptr) {
        HttpRequest::_sendNextRequest(httpReq);
    }
}

void HttpRequest::_attachPlatformObject(void *o) {}

void HttpRequest::_detachPlatformObject() {}

}
