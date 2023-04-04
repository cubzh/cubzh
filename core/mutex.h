// -------------------------------------------------------------
//  Cubzh Core
//  mutex.h
//  Created by Adrien Duermael on April 2, 2023.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#if defined(__VX_PLATFORM_WINDOWS)

#include <windows.h>

typedef HANDLE Mutex;

#else // non-Windows platforms

#include <pthread.h>

typedef pthread_mutex_t Mutex;

#endif // defined(__VX_PLATFORM_WINDOWS)

/// Alloc a Mutex
Mutex *mutex_new(void);

/// Free a Mutex
void mutex_free(Mutex *const m);

/// Locks a Mutex
void mutex_lock(Mutex *const m);

/// Unlocks a Mutex
void mutex_unlock(Mutex *const m);

#ifdef __cplusplus
} // extern "C"
#endif
