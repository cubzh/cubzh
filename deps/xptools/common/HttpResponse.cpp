//
//  HttpResponse.cpp
//  xptools
//
//  Created by Gaetan de Villele on 24/01/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#include "HttpResponse.hpp"

// C++
#include <string>

namespace vx {

HttpResponse::HttpResponse() :
_success(false),
_statusCode(0),
_headers(),
_bytes(),
_useLocalCache(false) {}

HttpResponse::~HttpResponse() {}

void HttpResponse::setSuccess(const bool& success) {
    _success = success;
}

const bool& HttpResponse::getSuccess() const {
    return _success;
}

void HttpResponse::setStatusCode(const uint16_t& statusCode) {
    this->_statusCode = statusCode;
}

const uint16_t& HttpResponse::getStatusCode() const {
    return _statusCode;
}

HTTPStatus HttpResponse::getStatus() const {

    if (_statusCode == 0) {
        return HTTPStatus::NETWORK;
    }

    if (_statusCode >= 500) {
        return HTTPStatus::INTERNAL_SERVER_ERROR;
    }

    if (_statusCode >= 400) {
        if (_statusCode == 401) {
            return HTTPStatus::UNAUTHORIZED;
        }
        if (_statusCode == 403) {
            return HTTPStatus::FORBIDDEN;
        }
        if (_statusCode == 404){
            return HTTPStatus::NOT_FOUND;
        }
        if (_statusCode == 409) {
            return HTTPStatus::CONFLICT;
        }
        return HTTPStatus::BAD_REQUEST;
    }

    if (_statusCode == 200) {
        return HTTPStatus::OK;
    }

    if (_statusCode == 304) {
        return HTTPStatus::NOT_MODIFIED;
    }

    return HTTPStatus::UNKNOWN;
}

void HttpResponse::setHeaders(std::unordered_map<std::string, std::string>&& headers) {
    this->_headers = headers;
}

void HttpResponse::setHeaders(const std::unordered_map<std::string, std::string>& headers) {
    this->_headers = headers;
}

const std::unordered_map<std::string, std::string>& HttpResponse::getHeaders() const {
    return _headers;
}

void HttpResponse::appendBytes(const std::string& bytes) {
    this->_bytes.append(bytes);
}

const std::string& HttpResponse::getBytes() const {
    return _bytes;
}

void HttpResponse::setBytes(const std::string& bytes) {
    this->_bytes.assign(bytes);
}

void HttpResponse::setUseLocalCache(const bool useLocalCache) {
    this->_useLocalCache = useLocalCache;
}

bool HttpResponse::getUseLocalCache() const {
    return _useLocalCache;
}

const std::string HttpResponse::getText() const {
    const size_t byteCount = _bytes.size(); // count of bytes
    // alloc string of size (byteCount + 1) to accomodate for trailing NULL char
    // (string is initialized with NULL chars)
    std::string text(byteCount + 1, '\0');
    // copy bytes into the string
    text.replace(0, byteCount, _bytes);
    return text;
}

// --------------------------------------------------
// MARK: - Private -
// --------------------------------------------------



}
