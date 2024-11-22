// -------------------------------------------------------------
//  Cubzh Core
//  weakptr.c
//  Created by Arthur Cormerais on October 27, 2021.
// -------------------------------------------------------------

#include "weakptr.h"

#include <stdlib.h>

#include "cclog.h"

struct _Weakptr {
    void *ptr;
    uint32_t refCount;
    int8_t autoFreeAt; // auto-invalidated and freed when reaching that ref count (most likely 1 or 0, <0 to disable)
    char pad[3];
};

Weakptr *weakptr_new(void *ptr) {
    Weakptr *wp = (Weakptr *)malloc(sizeof(Weakptr));
    wp->ptr = ptr;
    wp->refCount = 1;
    wp->autoFreeAt = -1;
    return wp;
}

Weakptr *weakptr_new_autofree(void *ptr, int8_t threshold) {
    Weakptr *wp = (Weakptr *)malloc(sizeof(Weakptr));
    wp->ptr = ptr;
    wp->refCount = 1;
    wp->autoFreeAt = threshold;
    return wp;
}

bool weakptr_retain(Weakptr *wptr) {
    if (wptr == NULL)
        return false;

    if (wptr->refCount < UINT32_MAX) {
        ++wptr->refCount;
        return true;
    } else {
        cclog_error("Weakptr: maximum refCount reached");
        return false;
    }
}

bool weakptr_release(Weakptr *wptr) {
    if (wptr == NULL)
        return false;

    --wptr->refCount;

    if (wptr->autoFreeAt >= 0 && wptr->refCount == wptr->autoFreeAt) {
        free(wptr->ptr);
        wptr->ptr = NULL;
    }
    
    if (wptr->refCount == 0) {
        free(wptr);
        return true;
    } else {
        return false;
    }
}

void *weakptr_get(const Weakptr *wptr) {
    if (wptr == NULL)
        return NULL;

    return wptr->ptr;
}

void *weakptr_get_or_release(Weakptr *wptr) {
    if (wptr == NULL)
        return NULL;

    if (wptr->ptr == NULL) {
        weakptr_release(wptr);
        return NULL;
    } else {
        return wptr->ptr;
    }
}

void weakptr_invalidate(Weakptr *wptr) {
    if (wptr == NULL)
        return;

    wptr->ptr = NULL;
    weakptr_release(wptr);
}
