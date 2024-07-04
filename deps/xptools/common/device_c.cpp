//
//  device_c.cpp
//  xptools
//
//  Created by Adrien Duermael on 04/22/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#include "device.h"
#include "device.hpp"

extern "C" {

bool c_hasTouchScreen(void) {
    return vx::device::hasTouchScreen();
}

bool c_hasMouseAndKeyboard(void) {
    return vx::device::hasMouseAndKeyboard();
}

int32_t device_timestampUnix(void) {
    return vx::device::timestampUnix();
}

int32_t device_timestampApple(void) {
    return vx::device::timestampApple();
}

const char* device_screen_allowed_orientation(void) {
    return vx::device::getScreenAllowedOrientation().c_str();
}

} // extern "C" 
