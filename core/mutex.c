// -------------------------------------------------------------
//  Cubzh Core
//  mutex.c
//  Created by Adrien Duermael on April 2, 2023.
// -------------------------------------------------------------

#include "mutex.h"

// C
#include <stdbool.h>
#include <stdlib.h>

// Core
#include "cclog.h"

#if defined(__VX_PLATFORM_WINDOWS)

/// Alloc a Mutex
Mutex *mutex_new(void) {
    Mutex *mtxPtr = (Mutex *)malloc(sizeof(Mutex));
    if (mtxPtr == NULL) {
        return NULL;
    }

    *mtxPtr = CreateMutex(NULL,  // default security attributes
                          FALSE, // initially not owned
                          NULL); // unnamed mutex

    if (*mtxPtr == NULL) {
        cclog_error("mutex_new failed: %d", GetLastError());
        return NULL;
    }

    return mtxPtr;
}

/// Free a Mutex
void mutex_free(Mutex *const m) {
    if (m == NULL) {
        cclog_error("mutex_free: mutex is NULL");
        return;
    }
    const bool ok = CloseHandle(*m);
    if (ok == false) {
        cclog_error("mutex_free: failed to close handle");
    }
    free(m);
}

void mutex_lock(Mutex *const m) {
    if (m == NULL) {
        return;
    }
    DWORD waitResult = WaitForSingleObject(*m, INFINITE);
    switch (waitResult) {
        // The thread got ownership of the mutex
        case WAIT_OBJECT_0:
            break;
        // The thread got ownership of an abandoned mutex
        // The database is in an indeterminate state
        case WAIT_ABANDONED:
            cclog_error("mutex_lock: failed to lock");
            break;
    }
}

void mutex_unlock(Mutex *const m) {
    if (m == NULL) {
        return;
    }
    const bool ok = ReleaseMutex(*m);
    if (ok == false) {
        cclog_error("mutex_unlock: failed to unlock");
    }
}

#else // non-Windows platforms

Mutex *mutex_new(void) {
    Mutex *mtx = (Mutex *)malloc(sizeof(pthread_mutex_t));
    if (mtx == NULL) {
        return NULL;
    }

    const int err = pthread_mutex_init((pthread_mutex_t *)mtx, NULL);
    if (err != 0) {
        // failure
        cclog_error("mutex_new failed: %d", err);
        free(mtx);
        return NULL;
    }

    return mtx;
}

void mutex_free(Mutex *const m) {
    if (m == NULL) {
        cclog_error("mutex_free: mutex is NULL");
        return;
    }
    const int err = pthread_mutex_destroy((pthread_mutex_t *)m);
    if (err != 0) {
        cclog_error("mutex_free: failed %d", err);
    }
    free(m);
}

void mutex_lock(Mutex *const m) {
    if (m == NULL) {
        return;
    }
    pthread_mutex_lock((pthread_mutex_t *)m);
}

void mutex_unlock(Mutex *const m) {
    if (m == NULL) {
        return;
    }
    pthread_mutex_unlock((pthread_mutex_t *)m);
}

#endif // defined(__VX_PLATFORM_WINDOWS)
