//
//  HttpResponse.cpp
//  xptools
//
//  Created by Gaetan de Villele on 24/01/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#include "HttpResponse.hpp"

// C++
#include <mutex>
#include <string>

namespace vx {

HttpResponse::HttpResponse() :
_success(false),
_downloadComplete(false),
_statusCode(0),
_headers(),
_bytes(),
_bytesLock(),
_useLocalCache(false) {}

HttpResponse::~HttpResponse() {}

void HttpResponse::setSuccess(const bool& value) {
    _success = value;
}

const bool& HttpResponse::getSuccess() const {
    return _success;
}

void HttpResponse::setDownloadComplete(const bool& value) {
    std::lock_guard<std::mutex> lock(_bytesLock);
    _downloadComplete = value;
}

const bool& HttpResponse::getDownloadComplete() const {
    std::lock_guard<std::mutex> lock(_bytesLock);
    return _downloadComplete;
}

void HttpResponse::setStatusCode(const uint16_t& value) {
    _statusCode = value;
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

void HttpResponse::setHeaders(std::unordered_map<std::string, std::string>&& value) {
    _headers = std::move(value);
}

void HttpResponse::setHeaders(const std::unordered_map<std::string, std::string>& value) {
    _headers = value;
}

const std::unordered_map<std::string, std::string>& HttpResponse::getHeaders() const {
    return _headers;
}

void HttpResponse::appendBytes(const std::string& bytes) {
    std::lock_guard<std::mutex> lock(_bytesLock);
    // _bytes.insert(_bytes.end(), bytes.begin(), bytes.end());
    _bytes.append(bytes);
}

void HttpResponse::readBytes(std::string& outBytes) {
    std::lock_guard<std::mutex> lock(_bytesLock);
    outBytes.assign(_bytes);
    _bytes.clear();
}

// TODO: gdevillele: _bytes.clear() has been commented in order for HTTP caching to work (see HttpClient::cacheHttpResponse)
bool HttpResponse::readAllBytes(std::string& outBytes) {
    std::lock_guard<std::mutex> lock(_bytesLock);
    if (_downloadComplete == false) {
        return false; // error
    }
    outBytes.assign(_bytes.begin(), _bytes.end());
    // _bytes.clear();
    return true;
}

size_t HttpResponse::availableBytes() const {
    std::lock_guard<std::mutex> lock(_bytesLock);
    return _bytes.size();
}

void HttpResponse::setUseLocalCache(const bool& value) {
    _useLocalCache = value;
}

const bool& HttpResponse::getUseLocalCache() const {
    return _useLocalCache;
}

}
