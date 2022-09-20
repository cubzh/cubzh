// -------------------------------------------------------------
//  Cubzh Core
//  filo_list.h
//  Created by Adrien Duermael on August 14, 2017.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef struct _FiloList FiloList;

FiloList *filo_list_new(void);

// ! \\ stored pointers won't be released
void filo_list_free(FiloList *list);

void filo_list_push(FiloList *list, void *ptr);

void *filo_list_pop(FiloList *list);

#ifdef __cplusplus
} // extern "C"
#endif
