//
//  device.h
//  xptools
//
//  Created by Adrien Duermael on 04/22/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#pragma once

// C
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// C wrapper for C++ filesystem functions

/// Returns true if device has a touch screen.
bool c_hasTouchScreen(void);

/// Returns true if device has a mouse and a keyboard.
bool c_hasMouseAndKeyboard(void);

/// same as vx::device::timestampUnix()
int32_t device_timestampUnix(void);

/// same as vx::device::timestampApple()
int32_t device_timestampApple(void);

#ifdef __cplusplus
} // extern "C"
#endif
