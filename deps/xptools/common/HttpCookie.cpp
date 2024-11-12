//
//  HttpCookie.cpp
//  xptools
//
//  Created by Gaetan de Villele on 26/01/2024.
//  Copyright © 2024 voxowl. All rights reserved.
//

#include "HttpCookie.hpp"

// C++
#include <string>
#include <sstream>

// xptools
#include "filesystem.hpp"
#include "json.hpp"

// deps
#include "cJSON.h"

namespace vx {
namespace http {

CookieStore *CookieStore::_sharedInstance = nullptr;
const std::string CookieStore::_domainFieldName = "domain";
const std::string CookieStore::_pathFieldName = "path";
const std::string CookieStore::_nameFieldName = "name";
const std::string CookieStore::_valueFieldName = "value";
const std::string CookieStore::_filePath = "/cookiestore.json";

Cookie::Cookie() :
_domain(),
_path(),
_name(),
_value(),
_secure(true),
_httpOnly(true) {}

bool Cookie::parseSetCookieHeader(const std::string &setCookieHeader, std::vector<Cookie> &cookies) {
    // Split the setCookieHeader by commas to isolate individual cookies
    std::istringstream cookieStream(setCookieHeader);
    std::string singleCookieStr;

    // Parse each cookie separated by comma
    while (std::getline(cookieStream, singleCookieStr, ',')) {
        Cookie c;
        std::istringstream stream(singleCookieStr);
        std::string directive;
        bool isFirstDirective = true;

        while (std::getline(stream, directive, ';')) {
            // Remove leading and trailing whitespaces
            const size_t firstNonSpace = directive.find_first_not_of(' ');
            const size_t lastNonSpace = directive.find_last_not_of(' ');

            if (firstNonSpace != std::string::npos && lastNonSpace != std::string::npos) {
                directive = directive.substr(firstNonSpace, lastNonSpace - firstNonSpace + 1);
            }

            // Split directive into key and value
            size_t equalsPos = directive.find('=');
            std::string key;
            std::string value;

            if (equalsPos != std::string::npos) {
                key = directive.substr(0, equalsPos);
                value = directive.substr(equalsPos + 1);
            } else {
                key = directive;
                value = "";
            }

            if (isFirstDirective) {
                // The first directive contains the cookie name and value
                c.setName(key);
                c.setValue(value);
                isFirstDirective = false;
            } else {
                // Process cookie attributes
                if (key == "Domain") {
                    c.setDomain(value);
                } else if (key == "Path") {
                    c.setPath(value);
                } else if (key == "HttpOnly" && value.empty()) {
                    c.setHttpOnly(true);
                } else if (key == "Secure" && value.empty()) {
                    c.setSecure(true);
                }
                // else if (key == "Max-Age") {
                //     c.setMaxAge(std::stoi(value));
                // }
                // Additional cookie attributes can be handled here
            }
        }

        // c.log();

        // Add parsed cookie to the cookies vector
        cookies.push_back(std::move(c));
    }

    return true; // success
}

// CookieStore

CookieStore &CookieStore::shared() {
    if (CookieStore::_sharedInstance == nullptr) {
        CookieStore::_sharedInstance = new CookieStore();
        CookieStore::_sharedInstance->_loadFromDisk();
    }
    return *CookieStore::_sharedInstance;
}

CookieStore::CookieStore() :
_cookies() {}

CookieStore::~CookieStore() {}

void CookieStore::setCookie(const Cookie newCookie) {
    // remove existing cookies that match the new one
    auto it = _cookies.begin();
    while (it != _cookies.end()) {
        // Check the condition and remove the element if it meets the criteria
        if (it->getDomain() == newCookie.getDomain() &&
            it->getName() == newCookie.getName()) {
            it = _cookies.erase(it);  // Erase returns the iterator to the next element after the erased one
        } else {
            ++it;  // Move to the next element
        }
    }

    _cookies.insert(newCookie);

    this->log();
    this->saveToDisk();
}

std::unordered_set<Cookie> CookieStore::getMatchingCookies(const std::string &domain, const std::string &path, const bool secure) const {
    std::unordered_set<Cookie> cookies;

    // TODO: filter also on path

    for (Cookie c : _cookies) {
        if (c.getDomain() == domain &&
            (secure == false || c.getSecure())) {
            cookies.insert(c);
        }
    }

    return cookies;
}

void CookieStore::removeAll() {
    _cookies.clear();
    saveToDisk();
}

void CookieStore::log() const {
    printf("--- COOKIE STORE ---\n");
    for (Cookie c : _cookies) {
        printf("%s | %s | %s | %s\n", c.getDomain().c_str(), c.getPath().c_str(), c.getName().c_str(), c.getValue().c_str());
    }
}

bool CookieStore::saveToDisk() {

    // construct JSON string representing the entire cookie collection
    cJSON *arr = cJSON_CreateArray();
    if (arr == nullptr) {
        return false;
    }
    for (Cookie c : _cookies) {
        // create JSON representation of the cookie
        cJSON *obj = cJSON_CreateObject();
        if (obj == nullptr) {
            cJSON_Delete(arr);
            return false;
        }
        vx::json::writeStringField(obj, _domainFieldName, c.getDomain());
        vx::json::writeStringField(obj, _pathFieldName, c.getPath());
        vx::json::writeStringField(obj, _nameFieldName, c.getName());
        // encode value into base64 ?
        vx::json::writeStringField(obj, _valueFieldName, c.getValue());

        cJSON_AddItemToArray(arr, obj);
    }

    // generate JSON string and free JSON resources
    char *jsonCStr = cJSON_Print(arr);
    cJSON_Delete(arr);
    arr = nullptr;

    if (jsonCStr == nullptr) {
        return false;
    }
    const std::string jsonStr(jsonCStr);
    free(jsonCStr);

    // write JSON on disk
    FILE *fd = ::vx::fs::openStorageFile(_filePath, "wb");
    if (fd == nullptr) {
        return false;
    }

    const size_t jsonStrLen = jsonStr.length();
    const size_t written = fwrite(jsonStr.c_str(), sizeof(char), jsonStrLen, fd);
    fclose(fd);

    return written == jsonStrLen;
}

bool CookieStore::_loadFromDisk() {

    // empty the cookie store
    _cookies.clear();

    // if file doesn't exist, we consider the loading a success
    if (vx::fs::storageFileExists(_filePath) == false) {
        return true;
    }

    // open/read/close JSON file on disk
    FILE *fd = ::vx::fs::openStorageFile(_filePath, "rb");
    if (fd == nullptr) {
        return false;
    }
    std::string jsonStr;
    const bool ok = vx::fs::getFileTextContentAsStringAndClose(fd, jsonStr);
    fd = nullptr;
    if (ok == false) {
        return false;
    }

    // parse JSON string
    cJSON *arr = cJSON_Parse(jsonStr.c_str());
    if (arr == nullptr) {
        return false;
    }
    if (cJSON_IsArray(arr) == false) {
        cJSON_Delete(arr);
        return false;
    }

    const int size = cJSON_GetArraySize(arr);
    cJSON *item = nullptr;
    for (int i = 0; i < size; i += 1) {
        item = cJSON_GetArrayItem(arr, i);
        if (item == nullptr) {
            continue;
        }

        Cookie c;
        std::string v;

        if (vx::json::readStringField(item, _domainFieldName, v)) {
            c.setDomain(v);
        }

        if (vx::json::readStringField(item, _pathFieldName, v)) {
            c.setPath(v);
        }

        if (vx::json::readStringField(item, _nameFieldName, v)) {
            c.setName(v);
        }

        if (vx::json::readStringField(item, _valueFieldName, v)) {
            c.setValue(v);
        }

        _cookies.insert(c);
    }

    cJSON_Delete(arr);
    return true;
}

}
}
