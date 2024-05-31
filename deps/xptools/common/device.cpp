//
//  device.cpp
//  xptools
//
//  Created by Gaetan de Villele on 12/10/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#include "device.hpp"

// C++
#include <cmath>
#include <ctime>

const std::string& vx::device::appVersionCached() {
    static std::string value;
    if (value.empty()) {
        value = vx::device::appVersion();
    }
    return value;
}

const std::string& vx::device::appBuildNumberCached() {
    static std::string value;
    if (value.empty()) {
        value = std::to_string(vx::device::appBuildNumber());
    }
    return value;
}

int32_t vx::device::timestampUnix() {
    const std::time_t t = std::time(nullptr);
    const int32_t result = static_cast<int32_t>(t);
    return result;
}

int32_t vx::device::timestampApple() {
    /// number of seconds between the Unix and Apple (Cocoa CoreData) timestamp representations of the same point in time
    #define TIMESTAMP_DELTA_UNIX_APPLE 978307200
    const int32_t result = vx::device::timestampUnix() - TIMESTAMP_DELTA_UNIX_APPLE;
    return result;
}

int vx::device::hardwareMemoryGB() {
    // 1024*1024*1024 = 1073741824
    const double f = hardwareMemory() / 1073741824.0;
    return static_cast<int>(floor(f + 0.5));
}
