// -------------------------------------------------------------
//  Cubzh Core
//  weakptr.h
//  Created by Arthur Cormerais on October 27, 2021.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

typedef struct _Weakptr Weakptr;

Weakptr *weakptr_new(void *ptr);
bool weakptr_retain(Weakptr *wptr);
bool weakptr_release(Weakptr *wptr);
void *weakptr_get(const Weakptr *wptr);
void *weakptr_get_or_release(Weakptr *wptr);
void weakptr_invalidate(Weakptr *wptr);

#ifdef __cplusplus
} // extern "C"
#endif
