//
//  HttpRequest.cpp
//  xptools
//
//  Created by Gaetan de Villele on 24/01/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#include "HttpRequest.hpp"

// C++
#include <cassert>

// xptools
#include "vxlog.h"
#include "HttpClient.hpp"
#include "WSService.hpp"
#include "ThreadManager.hpp"
#include "OperationQueue.hpp"
#include "HttpCookie.hpp"

using namespace vx;

#if defined(__VX_PLATFORM_WASM)
#define CUBZH_WASM_MAX_CONCURRENT_REQS 50
std::queue<HttpRequest_SharedPtr> HttpRequest::_requestsWaiting = std::queue<HttpRequest_SharedPtr>();
std::unordered_set<HttpRequest_SharedPtr> HttpRequest::_requestsFlying = std::unordered_set<HttpRequest_SharedPtr>();
std::mutex HttpRequest::_requestsMutex;
#endif

HttpRequest_SharedPtr HttpRequest::make(const std::string& method,
                                        const std::string& host,
                                        const uint16_t& port,
                                        const std::string& path,
                                        const QueryParams& queryParams,
                                        const bool& secure) {
    HttpRequest_SharedPtr r(new HttpRequest);
    r->_init(r, method, host, port, path, queryParams, secure);
    return r;
}

HttpRequest::~HttpRequest() {
    _detachPlatformObject();
}

void HttpRequest::setCallback(HttpRequestCallback callback) {
    _callback = callback;
}

bool HttpRequest::callCallback() {
	// vx::ThreadManager::shared().log("HttpRequest::callCallback");

    HttpRequest_SharedPtr strongSelf = this->_weakSelf.lock();
    if (strongSelf == nullptr) {
        return false;
    }
    if (strongSelf->getStatus() == CANCELLED) {
        // never trigger callback if request has been cancelled
        return false;
    }
    if (strongSelf->_callbackCalled == true) {
        vxlog_warning("HttpRequest callback is being called more than one time!");
        return false;
    }
    strongSelf->_callbackCalled = true;

#if defined(__VX_PLATFORM_WASM)
    vx::OperationQueue::getMain()->dispatch([strongSelf](){
#endif

// call response middleware
{
    auto respMiddleware = HttpClient::shared().getCallbackMiddleware();
    if (respMiddleware != nullptr) {
        respMiddleware(strongSelf);
    }
}

// Process Set-Cookie headers received
{
    auto headers = strongSelf->getResponse().getHeaders();
    // maybe we should remove the headers once they are processed
    for (auto header : headers) {
        // cubzh_test_cookie=yumyum; Domain=cu.bzh; HttpOnly; Secure
        if (header.first == "set-cookie") {
            vx::http::Cookie c;
            const bool ok = vx::http::Cookie::parseSetCookieHeader(header.second, c);
            if (ok) {
                vx::http::CookieStore::shared().setCookie(c);
            }
        }
    }
}

#if !defined(__VX_PLATFORM_WASM)
// if ETag was valid, we use the cached response
if (strongSelf->getResponse().getStatusCode() == HTTP_NOT_MODIFIED) {
    strongSelf->_useCachedResponse();
}

// Store response in cache (if conditions are met)
// optim possible: if it was a 304, we don't need to update the response bytes in the cache
const bool ok = vx::HttpClient::shared().cacheHttpResponse(strongSelf);
if (ok) {
    // vxlog_debug("HTTP response cached : %s", strongSelf->constructURLString().c_str());
}
#endif

if (strongSelf->_callback != nullptr) {
    strongSelf->_callback(strongSelf);
}

#if defined(__VX_PLATFORM_WASM)
    });
#endif

    return true;
}

const std::string& HttpRequest::getPathAndQuery() {

    // construct URL string
    _cache_pathAndQuery = _path;

    // add query params
    if (_queryParams.empty() == false) {
        bool isFirst = true;
        for (auto kv : _queryParams) {
            for (auto value : kv.second) {
                // add prefix
                _cache_pathAndQuery += isFirst ? "?" : "&";
                _cache_pathAndQuery += kv.first + "=" + value;
                isFirst = false;
            }
        }
    }

    return _cache_pathAndQuery;
}

void HttpRequest::sendAsync() {
	// vx::ThreadManager::shared().log("HttpRequest::sendAsync");

    HttpRequest_SharedPtr strongSelf = this->_weakSelf.lock();
    if (strongSelf == nullptr) {
        return;
    }

    // Add cookies to the request
    {
        std::unordered_set<http::Cookie> cookies = vx::http::CookieStore::shared().getMatchingCookies(strongSelf->getHost(),
                                                                                                      strongSelf->getPath(),
                                                                                                      strongSelf->getSecure());
        // Example:
        // Cookie: delicieux_cookie=choco; savoureux_cookie=menthe
        std::string cookieStr;
        for (vx::http::Cookie c : cookies) {
            if (cookieStr.empty() == false) {
                cookieStr += "; ";
            }
            cookieStr += c.getName() + "=" + c.getValue();
        }
        if (cookieStr.empty() == false) {
            strongSelf->setOneHeader("cookie", cookieStr);
        }
    }

    // Caching is not needed on WASM platform,
    // as the web browser is already taking care of it.
#if !defined(__VX_PLATFORM_WASM)
    // check if cache is available for GET requests
    if (this->getMethod() == "GET") {
        HttpClient::CacheMatch cacheMatch = vx::HttpClient::shared().getCachedResponseForRequest(strongSelf);
        if (cacheMatch.didFindCache &&
            cacheMatch.isStillFresh &&
            this->_opts.getForceCacheRevalidate() == false) {
            // use cached response
            strongSelf->_useCachedResponse();
            // apply cachedResponse to response
            // call request callback
            strongSelf->callCallback();
            return;
        }
    }
#endif

    if (this->_opts.getForceCacheRevalidate() == true) {
        strongSelf->_headers["Cache-Control"] = "no-cache";
    }

    // update status
    strongSelf->setStatus(HttpRequest::Status::PROCESSING);

    strongSelf->_sendAsync();
}

#if defined(__VX_PLATFORM_WASM)
void HttpRequest::_sendNextRequest(HttpRequest_SharedPtr reqToRemove) {
    HttpRequest_SharedPtr reqToSend = nullptr;

    HttpRequest::_requestsMutex.lock();

    if (reqToRemove != nullptr) {
        _requestsFlying.erase(reqToRemove);
    }

    while (HttpRequest::_requestsFlying.size() < CUBZH_WASM_MAX_CONCURRENT_REQS && HttpRequest::_requestsWaiting.empty() == false) {
        reqToSend = _requestsWaiting.front();
        _requestsWaiting.pop();
        if (reqToSend->getStatus() == Status::PROCESSING) {
        	// request is still waiting to be sent (it has not been cancelled)
         	_requestsFlying.insert(reqToSend);
          	reqToSend->_processAsync();
        }
    }

    HttpRequest::_requestsMutex.unlock();
}
#endif

void HttpRequest::sendSync() {
	// TODO: get strong reference

    std::mutex *mtx = new std::mutex();
    mtx->lock();

    this->setCallback([mtx](HttpRequest_SharedPtr req){
        mtx->unlock();
    });
    this->sendAsync();

    mtx->lock();
    mtx->unlock();
    delete mtx;
}

void HttpRequest::cancel() {
	// vx::ThreadManager::shared().log("HttpRequest::cancel");

	HttpRequest_SharedPtr strongSelf = this->_weakSelf.lock();
    if (strongSelf == nullptr) {
        return;
    }

#if defined(__VX_PLATFORM_WASM)
    vx::OperationQueue::getMain()->dispatch([strongSelf](){
#endif

        const Status previousStatus = strongSelf->getStatus();

        strongSelf->setStatus(HttpRequest::Status::CANCELLED);

        switch (previousStatus) {
            case Status::WAITING:
            case Status::PROCESSING:
                // continue to actually cancel the request
                break;
            case Status::FAILED:
            case Status::CANCELLED:
            case Status::DONE:
            case Status::CAN_BE_DESTROYED:
                // only set status
                // nothing else to do, request is done anyway
                return;
        }

        strongSelf->_cancel();

#if defined(__VX_PLATFORM_WASM)
    });
#endif
}

HttpResponse& HttpRequest::getResponse() {
    return this->_response;
}

HttpResponse& HttpRequest::getCachedResponse() {
    return this->_cachedResponse;
}

void HttpRequest::setCachedResponse(const bool success,
                                    const uint16_t statusCode,
                                    const std::unordered_map<std::string, std::string>& headers,
                                    const std::string bytes) {
    this->_cachedResponse.setSuccess(success);
    this->_cachedResponse.setStatusCode(statusCode);
    this->_cachedResponse.setHeaders(headers);
    this->_cachedResponse.appendBytes(bytes);
}

// Accessors

void HttpRequest::setBodyBytes(const std::string& bytes) {
    this->_bodyBytes.assign(bytes);
}

const std::string& HttpRequest::getBodyBytes() const {
    return this->_bodyBytes;
}

void HttpRequest::setOpts(const HttpRequestOpts& opts) {
    this->_opts = HttpRequestOpts(opts);
}

void HttpRequest::setHeaders(const std::unordered_map<std::string, std::string>& headers) {
#ifdef DEBUG
    // make sure headers' names don't end with a ':'
    for (auto pair : headers) {
        assert(pair.first.back() != ':');
    }
#endif

    this->_headers = headers;
    if (this->_headers.find("Accept") == this->_headers.end()) {
        this->_headers["Accept"] = "*/*";
    }

#if !defined(__VX_PLATFORM_WASM)
    // On non-web platforms, define the User-Agent as "Cubzh".
    // Web version doesn't override the User-Agent from the web browser.
    this->_headers["User-Agent"] = "Cubzh";
#endif
}

const std::unordered_map<std::string, std::string>& HttpRequest::getHeaders() const {
    return this->_headers;
}

void HttpRequest::setOneHeader(const std::string& key, const std::string& value) {
    this->_headers[key] = value;
}

// Returns current status (thread safe)
HttpRequest::Status HttpRequest::getStatus() {
    const std::lock_guard<std::mutex> locker(_statusMutex);
    HttpRequest::Status s = _status;
    return s;
}

// Sets status (thread safe)
void HttpRequest::setStatus(const HttpRequest::Status status) {
    const std::lock_guard<std::mutex> locker(_statusMutex);
    _status = status;
}

std::string HttpRequest::constructURLString() {
    const std::string scheme = _secure ? VX_HTTPS_SCHEME : VX_HTTP_SCHEME;
    // construct URL string
    const std::string urlStr = scheme + "://" + _host + ":" + std::to_string(_port) + getPathAndQuery();
    return urlStr;
}

// --------------------------------------------------
// MARK: - Private -
// --------------------------------------------------

HttpRequest::HttpRequest() :
_weakSelf(),
#if defined(__VX_PLATFORM_WASM)
_fetch(nullptr),
#endif
_method(),
_host(),
_port(0),
_path(),
_queryParams(),
_secure(false),
_headers(),
_bodyBytes(),
_written(0),
_callback(nullptr),
_callbackCalled(false),
_response(),
_cachedResponse(),
_statusMutex(),
_status(Status::WAITING),
_creationTime(std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch())),
_cache_pathAndQuery(),
_platformObject(nullptr) {}

void HttpRequest::_init(const HttpRequest_SharedPtr& ref,
                        const std::string& method,
                        const std::string& host,
                        const uint16_t& port,
                        const std::string& path,
                        const QueryParams& queryParams,
                        const bool& secure) {
    this->_weakSelf = ref;

    this->_method = method;
    this->_host = host;
    this->_port = port;
    this->_path = path;
    this->_queryParams = queryParams;
    this->_secure = secure;
}

#if !defined(__VX_PLATFORM_WASM)

void HttpRequest::_useCachedResponse() {
    HttpRequest_SharedPtr strongSelf = this->_weakSelf.lock();
    if (strongSelf == nullptr) {
        return;
    }
    // HTTP headers are not pulled from cache
    // doc: https://developer.mozilla.org/fr/docs/Web/HTTP/Status/304
    strongSelf->_response.setSuccess(strongSelf->_cachedResponse.getSuccess());
    strongSelf->_response.setStatusCode(strongSelf->_cachedResponse.getStatusCode());
    strongSelf->_response.setBytes(strongSelf->_cachedResponse.getBytes());
    strongSelf->_response.setUseLocalCache(strongSelf->_cachedResponse.getUseLocalCache());
}

#else // defined(__VX_PLATFORM_WASM)

void HttpRequest::downloadSucceeded(emscripten_fetch_t * const fetch) {
    HttpRequest::downloadCommon(fetch, true);
}

void HttpRequest::downloadFailed(emscripten_fetch_t * const fetch) {
    HttpRequest::downloadCommon(fetch, false);
}

void HttpRequest::downloadCommon(emscripten_fetch_t *fetch, bool success) {
	// vxlog_debug("🔥 fetch %d %p %s", fetch->id, fetch, success ? "success" : "fail");

    // retrieve pointer on request shared_ptr
    HttpRequest_SharedPtr *sptrRef = static_cast<HttpRequest_SharedPtr *>(fetch->userData);
    if (sptrRef == nullptr) {
        // can happen in case of cancelled request
        vxlog_debug("🔥 request has been released... (1)");
        return;
    }

    if (*sptrRef == nullptr) {
        vxlog_debug("🔥 request has been released... (2) SHOULD NOT HAPPEN");
        return;
    }

    HttpRequest_SharedPtr strongReq(*sptrRef);
    delete sptrRef;
    sptrRef = nullptr;
    fetch->userData = nullptr;

    if (strongReq->getStatus() == Status::CANCELLED) {
    	// vxlog_debug("🔥 request was cancelled %p", strongReq.get());
     	return;
    }

    if (strongReq->_fetch == nullptr) {
        vxlog_debug("🔥 request callback already called");
        return;
    }

    const uint16_t httpStatusCode = fetch->status;
    if (success == false && (httpStatusCode >= 100 && httpStatusCode <= 599)) {
        success = true;
    }

    const std::string bytes = std::string(fetch->data, fetch->numBytes);

    // free fetch memory
    const EMSCRIPTEN_RESULT closeResult = emscripten_fetch_close(fetch); // TODO: consider return value
    fetch = nullptr;
    strongReq->_fetch = nullptr;

    HttpRequest::downloadFinished(strongReq,
                                  success,
                                  httpStatusCode,
                                  bytes);
}

void HttpRequest::downloadFinished(HttpRequest_SharedPtr strongReq,
                                   const bool success,
                                   const uint16_t statusCode,
                                   const std::string bytes) {
    if (strongReq != nullptr) {
        Status reqStatus = strongReq->getStatus();

        if (reqStatus == Status::CANCELLED) {
            vxlog_debug("🔥 [HttpRequest] -> Request was cancelled.");

        } else if (reqStatus == Status::PROCESSING) {

            strongReq->_response.setSuccess(success);
            strongReq->_response.setStatusCode(statusCode);
            strongReq->_response.appendBytes(bytes);
            strongReq->callCallback();

        } else {
            vxlog_debug("🔥 [HttpRequest] -> unexpected status.");
        }

        // update status
        strongReq->setStatus(Status::CAN_BE_DESTROYED);
    }

    // process next request
    HttpRequest::_sendNextRequest(strongReq);
}

void HttpRequest::_processAsync() {
    HttpRequest_SharedPtr strongSelf = this->_weakSelf.lock();
    if (strongSelf == nullptr) {
        vxlog_error("HttpRequest aborted. Object is already released. (1)");
        return;
    }

    const Status status = strongSelf->getStatus();
    if (status != Status::PROCESSING) {
        return;
    }

    assert(this->_method == "GET" || this->_method == "POST" || this->_method == "PATCH");

    vx::OperationQueue::getMain()->dispatch([strongSelf](){

        const Status status = strongSelf->getStatus();
        if (status != Status::PROCESSING) {
            return;
        }

        assert(strongSelf->_method == "GET" || strongSelf->_method == "POST" || strongSelf->_method == "PATCH");

        HttpRequest_SharedPtr *sptrRef = new HttpRequest_SharedPtr(strongSelf);
        if (sptrRef == nullptr || (*sptrRef) == nullptr) {
            vxlog_error("HttpRequest aborted. Object is already released. (2)");
            return;
        }

        const std::string url = strongSelf->constructURLString();

        emscripten_fetch_attr_t attr;
        emscripten_fetch_attr_init(&attr);

        // store reference to the HttpRequest
        attr.userData = static_cast<void *>(sptrRef);

        // set HTTP method
        strcpy(attr.requestMethod, strongSelf->_method.c_str());

        // write custom headers
        {
            // +1 is for the trailing NULL pointer
            const int headersBufferSize = sizeof(char*) * ((strongSelf->getHeaders().size() * 2) + 1);
            attr.requestHeaders = (char**)malloc(headersBufferSize);

            const char * const *arr = attr.requestHeaders;
            char **arr2 = (char **)arr;

            int index = 0;
            for (const auto& kv : strongSelf->getHeaders()) {
                arr2[index] = (char*)kv.first.c_str();
                index++;
                arr2[index] = (char*)kv.second.c_str();
                index++;
            }
            arr2[index] = nullptr; // trailing NULL
        }

        // HTTP request body
        if (strongSelf->_method == "POST" || strongSelf->_method == "PATCH") {
            // define request body
            attr.requestData = strongSelf->_bodyBytes.c_str();
            attr.requestDataSize = strongSelf->_bodyBytes.size();
        } else if (strongSelf->_method == "GET") {
            // no request body
            attr.requestData = NULL;
            attr.requestDataSize = 0;
        }

        attr.attributes = EMSCRIPTEN_FETCH_LOAD_TO_MEMORY;

        // callbacks
        attr.onsuccess = HttpRequest::downloadSucceeded;
        attr.onerror = HttpRequest::downloadFailed;

        emscripten_fetch_t * const fetch = emscripten_fetch(&attr, url.c_str());

        // free headers array
        {
            char **arr = (char **)attr.requestHeaders;
            free(arr);
            attr.requestHeaders = nullptr;
        }

        // store fetch handle in HttpRequest object
        if (fetch != nullptr) {
            strongSelf->_fetch = fetch;
        } else {
            vxlog_error("fetch is NULL. Error is not handled yet.");
        }
    });
}

#endif
