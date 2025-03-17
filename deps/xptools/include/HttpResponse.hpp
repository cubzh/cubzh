//
//  HttpResponse.hpp
//  xptools
//
//  Created by Gaetan de Villele on 24/01/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#pragma once

// C++
#include <cstdint>
#include <mutex>
#include <string>
#include <unordered_map>
#include <limits>

namespace vx {

enum class HTTPStatus {
    OK,
    NOT_MODIFIED,
    INTERNAL_SERVER_ERROR,
    NETWORK,
    BAD_REQUEST,
    NOT_FOUND,
    UNAUTHORIZED,
    FORBIDDEN,
    UNKNOWN,
    CONFLICT,
};

class HttpResponse final {

public:
    
    HttpResponse();
    virtual ~HttpResponse();
    
    // accessors
    void setSuccess(const bool& value);
    const bool& getSuccess() const;

    void setDownloadComplete(const bool& value);
    const bool& getDownloadComplete() const;

    void setStatusCode(const uint16_t& value);
    const uint16_t& getStatusCode() const;
    HTTPStatus getStatus() const;

    void setHeaders(std::unordered_map<std::string, std::string>&& value);
    void setHeaders(const std::unordered_map<std::string, std::string>& value);
    const std::unordered_map<std::string, std::string>& getHeaders() const;

    // bytes buffer
    void appendBytes(const std::string& bytes);
    /// reads all available bytes, and clear the internal buffer
    void readBytes(std::string& outBytes);
    bool readAllBytes(std::string& outBytes);
    size_t availableBytes() const;

    void setUseLocalCache(const bool& value);
    const bool& getUseLocalCache() const;

private:

    /// indicates whether the connection was successful
    bool _success;

    /// indicates whether all bytes have been received or if we are still waiting for some
    bool _downloadComplete;

    /// HTTP status code
    uint16_t _statusCode;
    
    /// HTTP response headers
    std::unordered_map<std::string, std::string> _headers;
    
    /// Response body & its mutex
    std::string _bytes;
    mutable std::mutex _bytesLock;

    /// Indicates whether the response content is from local cache
    /// Note: if HttpRequest.opts.streamResponse == true, cache is never used for now.
    bool _useLocalCache;
};

}
