//
//  HttpRequest.hpp
//  xptools
//
//  Created by Gaetan de Villele on 24/01/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#pragma once

// C++
#include <functional>
#include <string>
#include <thread>
#include <memory>
#include <mutex>
#include <queue>
#include <unordered_map>

// xptools
#include "HttpRequestOpts.hpp"
#include "HttpResponse.hpp"
#include "URL.hpp"

// schemes
#define VX_HTTPS_SCHEME "https"
#define VX_HTTP_SCHEME "http"

// HTTP methods
#define VX_HTTPMETHOD_GET "GET"
#define VX_HTTPMETHOD_POST "POST"
#define VX_HTTPMETHOD_PATCH "PATCH"
#define VX_HTTPMETHOD_DELETE "DELETE"

#if defined(__VX_PLATFORM_WASM)
#include <stack>
#include <emscripten/fetch.h>
#endif

namespace vx {

// Types

class HttpRequest;
typedef std::shared_ptr<HttpRequest> HttpRequest_SharedPtr;
typedef std::weak_ptr<HttpRequest> HttpRequest_WeakPtr;
typedef std::function<void(HttpRequest_SharedPtr req)> HttpRequestCallback;
typedef std::unordered_map<std::string, std::string> HttpHeaders;

class HttpRequest final {

public:

    ///
    enum Status {
        WAITING = 1, // waiting to be sent
        PROCESSING = 2,
        FAILED = 3,
        CANCELLED = 4,
        DONE = 5,
        CAN_BE_DESTROYED = 6, // after callback has been called
    };

    /// Factory method
    static HttpRequest_SharedPtr make(const std::string& method,
                                      const std::string& host,
                                      const uint16_t& port,
                                      const std::string& path,
                                      const QueryParams& queryParams,
                                      const bool& secure);

    /// Destructor
    virtual ~HttpRequest();

    /// Performs the request and call the callback function
    void sendAsync();

    /// Performs the request in the current thread (it's blocking!)
    void sendSync();

    ///
    void cancel();

    ///
    HttpResponse& getResponse();

    ///
    void setCachedResponse(const bool success,
                           const uint16_t statusCode,
                           const std::unordered_map<std::string, std::string>& headers,
                           const std::string bytes);
    HttpResponse& getCachedResponse();

    // Accessors

    /// callback function will be called in the LWS service thread
    /// (not the main thread or calling thread)
    /// Note: it is best not to perform heavy tasks in this callback, so the
    /// LWS service thread is not slowed down.
    void setCallback(HttpRequestCallback callback);

    ///
    bool callCallback();

    inline const std::string& getMethod() const { return _method; }
    inline const std::string& getHost() const { return _host; }
    inline const std::string& getPath() const { return _path; }
    inline const uint16_t& getPort() const { return _port; }
    inline const bool& getSecure() const { return _secure; }
    /// Generates [path + query] string, cache the value and returns a reference on it.
    /// Note : caching the value is necessary because libwebsockets only uses a weak reference on it:
    /// `connectInfo.path = httpReq->getPathAndQuery().c_str();`
    const std::string& getPathAndQuery();

    ///
    void setBodyBytes(const std::string& bytes);

    ///
    const std::string& getBodyBytes() const;

    ///
    void setOpts(const HttpRequestOpts& opts);

    ///
    void setHeaders(const std::unordered_map<std::string, std::string>& headers);

    ///
    const std::unordered_map<std::string, std::string>& getHeaders() const;

    ///
    void setOneHeader(const std::string& key, const std::string& value);

    // Returns current status (thread safe)
    Status getStatus();

    // Sets status (thread safe)
    void setStatus(const Status status);

    inline void setWritten(const size_t& n) { _written = n; }
    inline size_t getWritten() { return _written; }

#if defined(__VX_PLATFORM_WASM)
    static void downloadSucceeded(emscripten_fetch_t * const fetch);
    static void downloadFailed(emscripten_fetch_t * const fetch);
    // used by downloadSucceeded and downloadFailed
    static void downloadCommon(emscripten_fetch_t *fetch, const bool success);
    static void downloadFinished(HttpRequest_SharedPtr req,
                                 const bool success,
                                 const uint16_t statusCode,
                                 const std::string bytes);
#endif

    inline std::chrono::milliseconds getCreationTime() { return _creationTime; }

    /// generate URL string
    std::string constructURLString();

private:

#if defined(__VX_PLATFORM_WASM)
    static std::stack<HttpRequest_SharedPtr> _requestsWaiting;
    static std::unordered_set<HttpRequest_SharedPtr> _requestsFlying;
    static std::mutex _requestsMutex;
    static void _sendNextRequest(HttpRequest_SharedPtr reqToRemove);
#endif

    /// Constructor
    HttpRequest();

    /// Init
    void _init(const HttpRequest_SharedPtr& ref,
               const std::string& method,
               const std::string& host,
               const uint16_t& port,
               const std::string& path,
               const QueryParams& queryParams,
               const bool& secure);

    ///
    HttpRequest_WeakPtr _weakSelf;

#if defined(__VX_PLATFORM_WASM)
    /// sends HTTP request asynchronously
    void _processAsync();

    ///
    emscripten_fetch_t *_fetch;
#else
    void _useCachedResponse();
#endif

    /// Request fields
    std::string _method;
    std::string _host;
    uint16_t _port;
    std::string _path;
    QueryParams _queryParams;
    bool _secure;
    HttpRequestOpts _opts;
    std::unordered_map<std::string, std::string> _headers;

    // POST request
    std::string _bodyBytes;
    // keeping track of written bytes,
    // bodies can be sent using several lws calls
    size_t _written;

    ///
    HttpRequestCallback _callback;

    /// indicates whether the callback has been called
    bool _callbackCalled;

    /// HttpResponse
    HttpResponse _response;

    ///
    HttpResponse _cachedResponse;

    ///
    std::mutex _statusMutex;
    Status _status;

    /// Request creation timestamp (ms)
    std::chrono::milliseconds _creationTime;

    // cached values
    std::string _cache_pathAndQuery;

    // ------------------
    // platform specific
    // ------------------

    void _sendAsync();
    void _cancel();

    void *_platformObject;
    void _attachPlatformObject(void *o);
    void _detachPlatformObject();
};

}
