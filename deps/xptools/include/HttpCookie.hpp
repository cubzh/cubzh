//
//  HttpCookie.hpp
//  xptools
//
//  Created by Gaetan de Villele on 26/01/2024.
//  Copyright © 2024 voxowl. All rights reserved.
//

#pragma once

// C++
#include <string>
#include <unordered_set>
#include <vector>

namespace vx {
namespace http {

class Cookie final {
public:
    // Returns true on success
    static bool parseSetCookieHeader(const std::string &setCookieHeader, std::vector<Cookie> &cookie);

    Cookie();
    // ~Cookie();

    inline void setDomain(const std::string &nv) {_domain = nv;}
    inline void setPath(const std::string &nv) {_path = nv;}
    inline void setName(const std::string &nv) {_name = nv;}
    inline void setValue(const std::string &nv) {_value = nv;}
    inline void setSecure(const bool &nv) {_secure = nv;}
    inline void setHttpOnly(const bool &nv) {_httpOnly = nv;}
    // inline void setMaxAge(const int &nv) {_maxAge = nv;}

    inline const std::string& getDomain() const {return _domain;}
    inline const std::string& getPath() const {return _path;}
    inline const std::string& getName() const {return _name;}
    inline const std::string& getValue() const {return _value;}
    inline const bool& getSecure() const {return _secure;}
    inline const bool& getHttpOnly() const {return _httpOnly;}
    // inline const int& getMaxAge() const {return _maxAge;}

    // Override the equality operator
    bool operator==(const Cookie& other) const {
        return (this->_domain == other.getDomain() &&
                this->_path == other.getPath() &&
                this->_name == other.getName());
    }

    inline void log() const {
        printf("[COOKIE] %s %s %s %s Secure=%s HttpOnly=%s\n",
               getDomain().c_str(), getPath().c_str(), getName().c_str(), getValue().c_str(),
               getSecure() ? "YES" : "NO", getHttpOnly() ? "YES" : "NO");
    }

private:
    std::string _domain;
    std::string _path;
    std::string _name;
    std::string _value;
    bool _secure;
    bool _httpOnly;
    // int _maxAge;
};

}
}

namespace std {
template <>
struct hash<vx::http::Cookie> {
    size_t operator()(const vx::http::Cookie& c) const {
        // Concatenate the strings
        const std::string combined = "d" + c.getDomain() + "p" + c.getPath() + "n" + c.getName();

        // Use std::hash to hash the concatenated string
        return std::hash<std::string>{}(combined);
    }
};
}

namespace vx {
namespace http {

class CookieStore final {
public:
    static CookieStore &shared();

    ~CookieStore();

    // accessors
    std::unordered_set<Cookie> getMatchingCookies(const std::string &domain, const std::string &path, const bool secure) const;
    void removeAll();
    void log() const;

    // modifiers
    void setCookie(const Cookie c);
    bool saveToDisk();

private:
    static CookieStore *_sharedInstance;
    static const std::string _domainFieldName;
    static const std::string _pathFieldName;
    static const std::string _nameFieldName;
    static const std::string _valueFieldName;
    static const std::string _filePath;

    CookieStore();

    bool _loadFromDisk();

    std::unordered_set<Cookie> _cookies;
};

}
}
