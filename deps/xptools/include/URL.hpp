//
//  URL.hpp
//  xptools
//
//  Created by Gaetan de Villele on 02/04/2023.
//  Copyright © 2023 voxowl. All rights reserved.
//

#pragma once

// C++
#include <unordered_map>
#include <unordered_set>

#define HTTP_PORT 80
#define HTTPS_PORT 443
#define CUBZH_PORT 0

namespace vx {

///
typedef std::unordered_map<std::string,std::unordered_set<std::string>> QueryParams;

///
class URL final {
public:

    ///
    static URL make(const std::string& urlString, const std::string& defaultScheme = "");

    /// destructor
    ~URL();

    /// copy constructor
    URL(URL const&) = default;

    // accessors

    inline const QueryParams& queryParams() const { return _queryParams; }
    inline const std::string& scheme() const { return _scheme; }
    inline const std::string& host() const { return _host; }
    inline const std::string& path() const { return _path; }
    inline const uint16_t& port() const { return _port; }
    inline const bool& isValid() const { return _isValid; }

    /// Returns true if the key is found and at least one value is associated with the key, and false otherwise
    bool queryContainsKey(const std::string& key) const;
    /// Returns the number of values associated with the given key
    size_t queryValueCountForKey(const std::string& key) const;
    /// Returns a copy of the values associated with the given key, or an empty set if the key is not found.
    std::unordered_set<std::string> queryValuesForKey(const std::string& key) const;

    // modifiers

    inline void setPort(const uint16_t& value) { _port = value; }

    void setQuery(const QueryParams& queryParams);
    void setQuery(QueryParams&& queryParams);

private:

    ///
    static bool _parseURLString(const std::string& urlString,
                                std::string& outScheme,
                                std::string& outHost,
                                uint16_t& outPort,
                                std::string& outPath,
                                QueryParams& outQueryParams,
                                const std::string& defaultScheme);

    /// default constructor
    URL();

    QueryParams _queryParams;
    std::string _scheme;
    std::string _host;
    std::string _path;
    uint16_t _port;
    bool _isValid;
};

}
