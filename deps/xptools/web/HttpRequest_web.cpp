
#include "HttpRequest.hpp"
#include "WSService.hpp"

namespace vx {

void HttpRequest::_sendAsync(HttpRequest_SharedPtr httpReq) {

	// ensure <self> has not been released
	HttpRequest_SharedPtr strongSelf = this->_weakSelf.lock();
    if (strongSelf == nullptr) {
        return;
    }

    HttpRequest::_requestsMutex.lock();
    HttpRequest::_requestsWaiting.push(strongSelf);
    HttpRequest::_requestsMutex.unlock();
    HttpRequest::_sendNextRequest(nullptr);
}

void HttpRequest::_cancel(HttpRequest_SharedPtr httpReq) {

	// ensure `self` has not been released
	HttpRequest_SharedPtr strongSelf = this->_weakSelf.lock();
    if (strongSelf == nullptr) {
        return;
    }

    if (strongSelf->_fetch != nullptr) { // request is flying
        emscripten_fetch_close(strongSelf->_fetch); // cancel request
        strongSelf->_fetch = nullptr;
    }

    HttpRequest::_sendNextRequest(strongSelf);
}

void HttpRequest::_attachPlatformObject(void *o) {}

void HttpRequest::_detachPlatformObject() {}

}
