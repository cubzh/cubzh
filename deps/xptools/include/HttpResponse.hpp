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
#include <string>
#include <unordered_map>

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

enum class HTTPResponseType {
    DEFAULT,
    PARTIAL_FIRST,
    PARTIAL_BYTES,
    PARTIAL_END,
};

// Add this after the enum definition
inline const char* HTTPResponseTypeToStr(HTTPResponseType type) {
    switch (type) {
        case HTTPResponseType::DEFAULT:       return "DEFAULT";
        case HTTPResponseType::PARTIAL_FIRST: return "PARTIAL_FIRST";
        case HTTPResponseType::PARTIAL_BYTES: return "PARTIAL_BYTES";
        case HTTPResponseType::PARTIAL_END:   return "PARTIAL_END";
        default:                             return "UNKNOWN";
    }
}
class HttpResponse final {

public:
    
    HttpResponse();
    virtual ~HttpResponse();
    
    // accessors
    void setSuccess(const bool& success);
    const bool& getSuccess() const;

    void setResponseType(const HTTPResponseType& type);
    const HTTPResponseType& getResponseType() const;

    void setStatusCode(const uint16_t& statusCode);
    const uint16_t& getStatusCode() const;
    HTTPStatus getStatus() const;

    void appendBytes(const std::string& bytes);
    const std::string& getBytes() const;
    void setBytes(const std::string& bytes);

    void setHeaders(std::unordered_map<std::string, std::string>&& headers);
    void setHeaders(const std::unordered_map<std::string, std::string>& headers);
    const std::unordered_map<std::string, std::string>& getHeaders() const;

    void setUseLocalCache(const bool useLocalCache);
    bool getUseLocalCache() const;

    /// TODO: should be removed once we support HTTP headers for the response
    /// -> if we have a Content-Type header with application/json or other text
    ///    formats, the _bytes field should have a trailing NULL character.
    const std::string getText() const;
    
private:

    /// indicates whether the connection was successful
    bool _success;

    /// indicates what kind of response it is (complete, partial)
    HTTPResponseType _responseType;

    /// HTTP status code
    /// Used for response types `DEFAULT` and `PARTIAL_FIRST`
    uint16_t _statusCode;
    
    /// HTTP headers
    /// Used for response types `DEFAULT` and `PARTIAL_FIRST`
    std::unordered_map<std::string, std::string> _headers;
    
    /// Response body
    /// Used for response types `DEFAULT`, `PARTIAL_FIRST` and `PARTIAL_BYTES`
    std::string _bytes;

    /// Indicates whether the response content is from local cache
    bool _useLocalCache;
};

}
