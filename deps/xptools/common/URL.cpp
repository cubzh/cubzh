//
//  URL.cpp
//  xptools
//
//  Created by Gaetan de Villele on 02/04/2023.
//  Copyright © 2023 voxowl. All rights reserved.
//

// C++
#include <regex>
#include <string>

// xptools
#include "URL.hpp"
#include "strings.hpp"

using namespace vx;

// URL implementation

URL URL::make(const std::string &urlString, const std::string& defaultScheme) {
    URL url;
    url._isValid = URL::_parseURLString(urlString,
                                        url._scheme,
                                        url._host,
                                        url._port,
                                        url._path,
                                        url._queryParams,
                                        defaultScheme);
    return url;
}

URL::URL() :
_isValid(false) {}

URL::~URL() {}

// MARK: - Accessors -

bool URL::queryContainsKey(const std::string& key) const {
    return (_queryParams.find(key) != _queryParams.end() && // key found
            _queryParams.at(key).empty() == false); // at least one value is present
}

size_t URL::queryValueCountForKey(const std::string& key) const {
    if (_queryParams.find(key) != _queryParams.end()) {
        return _queryParams.at(key).size();
    }
    return 0;
}

std::unordered_set<std::string> URL::queryValuesForKey(const std::string& key) const {
    std::unordered_set<std::string> values;
    if (this->queryContainsKey(key)) {
        values = _queryParams.at(key);
    }
    return values;
}

void URL::setQuery(const QueryParams& queryParams) {
    this->_queryParams = queryParams;
}

void URL::setQuery(QueryParams&& queryParams) {
    this->_queryParams = queryParams;
}

bool URL::_parseURLString(const std::string& urlString,
                          std::string& outScheme,
                          std::string& outHost,
                          uint16_t& outPort,
                          std::string& outPath,
                          QueryParams& outQueryParams,
                          const std::string& defaultScheme) {
    if (urlString.empty()) {
        return false;
    }

    std::string urlStringToParse = urlString;

    // add scheme prefix if not present
    {
        const bool schemePresent = urlString.find("://") != urlString.npos;
        if (schemePresent == false) {
            urlStringToParse = defaultScheme + "://" + urlStringToParse;
        }
    }

    // Regular expression to extract the various components of the URL
    std::regex url_regex(R"(^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?)");
    std::smatch url_match;
    const bool regexOk = std::regex_match(urlStringToParse, url_match, url_regex);
    if (regexOk == false) {
        return false;
    }

    // std::cout << "Protocol: " << url_match[2].str() << std::endl;
    // std::cout << "Host: " << url_match[4].str() << std::endl;
    // std::cout << "Path: " << url_match[5].str() << std::endl;
    // std::cout << "Query string: " << url_match[7].str() << std::endl;
    // std::cout << "Fragment: " << url_match[9].str() << std::endl;

    outScheme.clear();
    outHost.clear();
    outPort = 0;
    outPath.clear();
    outQueryParams.clear();

    // scheme
    {
        outScheme = url_match[2];
    }

    // host & port
    {
        outHost = url_match[4].str();
        // check if a port is present in the URL (':' char)
        if (outHost.find(':') == std::string::npos) {
            // ':' not found
            if (outScheme == "http") {
                outPort = HTTP_PORT;
            } else if (outScheme == "https") {
                outPort = HTTPS_PORT;
            } else if (outScheme == "cubzh") {
                outPort = CUBZH_PORT;
            } else {
                return false; // not supported, return an error
            }
        } else { // ':' is present
            std::vector<std::string> elements = vx::str::splitString(outHost, ":");
            if (elements.size() != 2) {
                return false; // error
            }
            const std::string portStr = elements.back();
            outPort = std::stoi(portStr);
            // remove the port suffix
            outHost = outHost.substr(0, outHost.length() - (portStr.length() + 1)); // +1 is length of ":"
        }
    }

    // path
    {
        outPath = url_match[5];
    }

    // query params
    {
        // foo=bar&bar=baz
        const std::string query = url_match[7];
        if (query.empty() == false) {
            // Regular expression to match a single key-value pair in the query string
            std::regex key_value_regex("([\\w+%]+)=([^&]*)");
            auto query_begin = std::sregex_iterator(query.begin(), query.end(), key_value_regex);
            auto query_end = std::sregex_iterator();

            for (std::sregex_iterator i = query_begin; i != query_end; ++i) {
                std::smatch match = *i;
                std::string key = match.str(1);
                std::string value = match.str(2);
                // vxlog_debug("[kv]> %s : %s", key.c_str(), value.c_str());

                std::unordered_set<std::string>& values = outQueryParams[key];
                values.insert(value);
            }
        }
    }

    return true;
}
