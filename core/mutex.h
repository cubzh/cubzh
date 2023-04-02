// -------------------------------------------------------------
//  Cubzh Core
//  mutex.h
//  Created by Adrien Duermael on April 2, 2023.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <pthread.h>

typedef pthread_mutex_t Mutex;

//Mutex* mutex_new(void);
//void mutex_free(Mutex *m);

void mutex_lock(Mutex *m);
void mutex_unlock(Mutex *m);

#ifdef __cplusplus
} // extern "C"
#endif
