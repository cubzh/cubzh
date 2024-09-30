
#include "HttpRequest.hpp"
#include "WSService.hpp"

namespace vx {

void HttpRequest::_sendAsync(HttpRequest_SharedPtr httpReq) {
    WSService::shared()->sendHttpRequest(httpReq);
}

void HttpRequest::_cancel(HttpRequest_SharedPtr httpReq) {
    WSService::shared()->cancelHttpRequest(httpReq);
}

void HttpRequest::_attachPlatformObject(void *o) {}

void HttpRequest::_detachPlatformObject() {}

}
