// -------------------------------------------------------------
//  Cubzh Core
//  mutex.c
//  Created by Adrien Duermael on April 2, 2023.
// -------------------------------------------------------------

#include "mutex.h"

void mutex_lock(Mutex *m) {
    pthread_mutex_lock((pthread_mutex_t*)m);
}

void mutex_unlock(Mutex *m) {
    pthread_mutex_unlock((pthread_mutex_t*)m);
}
