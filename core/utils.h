// -------------------------------------------------------------
//  Cubzh Core
//  utils.h
//  Created by Adrien Duermael on September 12, 2020.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// C
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "cclog.h"
#include "config.h"
#include "float3.h"

#if defined(DEBUG)

#define RETURN_IF_NULL(PTR)                                                                        \
    if (PTR == NULL) {                                                                             \
        cclog_warning("pointer is NULL - %sL%d", __FILE__, __LINE__);                              \
        return;                                                                                    \
    }

#define RETURN_VALUE_IF_NULL(PTR, RETURN_VALUE)                                                    \
    if (PTR == NULL) {                                                                             \
        cclog_warning("pointer is NULL - %sL%d", __FILE__, __LINE__);                              \
        return RETURN_VALUE;                                                                       \
    }

#else

#define RETURN_IF_NULL(PTR)
#define RETURN_VALUE_IF_NULL(PTR, RETURN_VALUE)

#endif

int8_t utils_radians_to_int8(float radians);

float utils_int8_to_radians(float i);

// enforce radians between -pi and pi
float utils_radians_normalize(float radians);

float utils_deg2Rad(float deg);
float utils_rad2Deg(float rad);

bool float_isEqual(const float f1, const float f2, const float epsilon);
bool float_isZero(const float f, const float epsilon);

bool utils_is_float_to_coords_inbounds(const float value);
bool utils_is_float3_to_coords_inbounds(const float x, const float y, const float z);

FACE_INDEX_INT_T utils_aligned_normal_to_face(const float3 *normal);

// MARK: - Axes mask -

typedef enum {
    AxesMaskNone = 0,
    AxesMaskX = 1,
    AxesMaskNX = 2,
    AxesMaskY = 4,
    AxesMaskNY = 8,
    AxesMaskZ = 16,
    AxesMaskNZ = 32,
    AxesMaskAll = 63
} AxesMaskValue;

typedef enum {
    AxisIndexX = 0,
    AxisIndexNX = 1,
    AxisIndexY = 2,
    AxisIndexNY = 3,
    AxisIndexZ = 4,
    AxisIndexNZ = 5
} AxisIndex;

void utils_axes_mask_set(uint8_t *mask, const uint8_t value, const bool toggle);
bool utils_axes_mask_get(const uint8_t mask, const uint8_t value);
void utils_axes_mask_set_from_vector(uint8_t *mask, const float3 *v);
void utils_axes_mask_set_from_normal(uint8_t *mask, const float3 *n);
FACE_INDEX_INT_T utils_axes_mask_value_to_face(AxesMaskValue v);
uint8_t utils_axes_mask_swapped(uint8_t mask);
AxesMaskValue utils_axes_mask_value_swapped(AxesMaskValue v);
AxesMaskValue utils_axis_index_to_mask_value(AxisIndex idx);

// MARK: - Strings / string arrays -

#define NUMARGS(...) (sizeof((const char *[]){__VA_ARGS__}) / sizeof(const char *))
#define string_new_join(...) (_string_new_join(NUMARGS(__VA_ARGS__), __VA_ARGS__))

typedef struct _stringArray_t stringArray_t;

/// Allocates and returns a new string joining parameter strings.
/// The returned string is a NULL-terminated string.
/// The caller is responsible for freeing the returned string.
/// Note: use the macro for nbArgs to be defined automatically
char *_string_new_join(int nbArgs, ...);

/// Allocates and returns a new string, copy of provided NULL-terminated string.
char *string_new_copy(const char *src);

/// Allocates and returns a new string, portion of provided NULL-terminated string.
char *string_new_substring(const char *start, const char *end);

// Same as string_new_copy with limited number of chars
char *string_new_copy_with_limit(const char *src, const size_t len);

// Splits string with char delimiters.
// (all delimiter chars in string parameter considered)
stringArray_t *string_split(const char *path, const char *delimiters);

/// allocates and return an empty stringArray
stringArray_t *stringArray_new(void);

/// frees a stringArray including its entire content.
void stringArray_free(stringArray_t *arr);

/// Appends a copy of the "str" argument at the end of a stringArray_t.
/// Returns true on success, false otherwise.
/// with n limit of chars
bool stringArray_n_append(stringArray_t *arr, const char *str, size_t length);

/// Returns the length of a stringArray_t or -1 on error.
int stringArray_length(stringArray_t *arr);

/// Returns a pointer on the array data.
const char *stringArray_get(const stringArray_t *arr, const int idx);

char *utils_get_baked_fullname(const char *id, const char *itemFullname);

void utils_rgba_to_uint8(uint32_t rgba, uint8_t *out);
uint32_t utils_uint8_to_rgba(uint8_t r, uint8_t g, uint8_t b, uint8_t a);
void utils_rgba_to_float(uint32_t rgba, float *out);

#ifdef __cplusplus
} // extern "C"
#endif
