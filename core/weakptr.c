// -------------------------------------------------------------
//  Cubzh Core
//  weakptr.c
//  Created by Arthur Cormerais on October 27, 2021.
// -------------------------------------------------------------

#include "weakptr.h"

#include <stdint.h>
#include <stdlib.h>

#include "cclog.h"

struct _Weakptr {
    void *ptr;
    uint32_t refCount;
    char pad[4];
};

Weakptr *weakptr_new(void *ptr) {
    Weakptr *wp = (Weakptr *)malloc(sizeof(Weakptr));
    wp->ptr = ptr;
    wp->refCount = 1;
    return wp;
}

bool weakptr_retain(Weakptr *wptr) {
    if (wptr == NULL)
        return false;

    if (wptr->refCount < UINT32_MAX) {
        ++(wptr->refCount);
        return true;
    } else {
        cclog_error("Weakptr: maximum refCount reached");
        return false;
    }
}

bool weakptr_release(Weakptr *wptr) {
    if (wptr == NULL)
        return false;

    if (--(wptr->refCount) == 0) {
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
