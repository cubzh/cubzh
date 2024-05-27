//
//  HttpRequestOpts.hpp
//  xptools
//
//  Created by Gaetan de Villele on 19/11/2023.
//  Copyright © 2023 voxowl. All rights reserved.
//

#pragma once

namespace vx {

class HttpRequestOpts final {
public:

    static HttpRequestOpts defaults;

    inline HttpRequestOpts() :
    _forceCacheRevalidate(false),
    _sendNow(true) {}

    // accessors

    inline bool getForceCacheRevalidate() const { return _forceCacheRevalidate; }
    inline bool getSendNow() const { return _sendNow; }

    // modifiers

    inline void setForceCacheRevalidate(const bool& value) { _forceCacheRevalidate = value; }
    inline void setSendNow(const bool& value) { _sendNow = value; }

private:

    bool _forceCacheRevalidate;
    bool _sendNow;
};

} // namespace vx
