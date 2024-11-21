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
#include <stdint.h>

typedef struct _Weakptr Weakptr;

Weakptr *weakptr_new(void *ptr);
Weakptr *weakptr_new_autofree(void *ptr, int8_t threshold); // auto-invalidated & freed when ref is decremented to threshold for the first time
bool weakptr_retain(Weakptr *wptr);
bool weakptr_release(Weakptr *wptr);
void *weakptr_get(const Weakptr *wptr);
void *weakptr_get_or_release(Weakptr *wptr);
void weakptr_invalidate(Weakptr *wptr);

#ifdef __cplusplus
} // extern "C"
#endif
