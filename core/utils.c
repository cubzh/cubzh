// -------------------------------------------------------------
//  Cubzh Core
//  utils.c
//  Created by Adrien Duermael on September 12, 2020.
// -------------------------------------------------------------

#include "utils.h"

#include <math.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "config.h"

int8_t utils_radians_to_int8(float radians) {
    return (int8_t)(radians * 128.0f / PI_F);
}

float utils_int8_to_radians(float i) {
    return i * PI_F / 128.0f;
}

float utils_radians_normalize(float radians) {
    while (radians < -PI_F) {
        radians += 2.0f * PI_F;
    }
    while (radians > PI_F) {
        radians -= 2.0f * PI_F;
    }
    return radians;
}

float utils_deg2Rad(float deg) {
    return deg * DEGREES_TO_RADIANS_F;
}

float utils_rad2Deg(float rad) {
    return rad / DEGREES_TO_RADIANS_F;
}

bool float_isEqual(const float f1, const float f2, const float epsilon) {
    const float diff = fabsf(f1 - f2);

    // return if diff already under epsilon
    if (diff < epsilon) {
        return true;
    }

    // tolerance given by epsilon should be scaled based on f1 & f2
    if (diff < maximum(fabsf(f1), fabsf(f2)) * epsilon) {
        return true;
    }

    return false;
}

bool float_isZero(const float f, const float epsilon) {
    return fabsf(f) < epsilon;
}

bool utils_is_float_to_coords_inbounds(const float value) {
    return value >= ((float)INT16_MIN) && value <= ((float)INT16_MAX);
}

bool utils_is_float3_to_coords_inbounds(const float x, const float y, const float z) {
    return utils_is_float_to_coords_inbounds(x) && utils_is_float_to_coords_inbounds(y) &&
           utils_is_float_to_coords_inbounds(z);
}

FACE_INDEX_INT_T utils_aligned_normal_to_face(const float3 *normal) {
    // note: we use comparison between components instead of checking for 1's, to make sure we
    // always return something even if it's an approximation, never return FACE_NONE
    if (fabsf(normal->x) >= fabsf(normal->y) && fabsf(normal->x) >= fabsf(normal->z)) {
        return normal->x > 0.0f ? FACE_RIGHT : FACE_LEFT;
    } else if (fabsf(normal->y) >= fabsf(normal->x) && fabsf(normal->y) >= fabsf(normal->z)) {
        return normal->y > 0.0f ? FACE_TOP : FACE_DOWN;
    } else {
        return normal->z > 0.0f ? FACE_FRONT : FACE_BACK;
    }
}

void utils_axes_mask_set(uint8_t *mask, const uint8_t value, const bool toggle) {
    if (toggle) {
        *mask = *mask | value;
    } else {
        *mask = *mask & ~value;
    }
}

bool utils_axes_mask_get(const uint8_t mask, const uint8_t value) {
    return (mask & value) == value;
}

void utils_axes_mask_set_from_vector(uint8_t *mask, const float3 *v) {
    *mask = *mask | (v->x > 0.0f ? AxesMaskX : 0) | (v->x < 0.0f ? AxesMaskNX : 0) |
            (v->y > 0.0f ? AxesMaskY : 0) | (v->y < 0.0f ? AxesMaskNY : 0) |
            (v->z > 0.0f ? AxesMaskZ : 0) | (v->z < 0.0f ? AxesMaskNZ : 0);
}

void utils_axes_mask_set_from_normal(uint8_t *mask, const float3 *n) {
    *mask = *mask | (n->x > 0.0f ? AxesMaskNX : 0) | (n->x < 0.0f ? AxesMaskX : 0) |
            (n->y > 0.0f ? AxesMaskNY : 0) | (n->y < 0.0f ? AxesMaskY : 0) |
            (n->z > 0.0f ? AxesMaskNZ : 0) | (n->z < 0.0f ? AxesMaskZ : 0);
}

FACE_INDEX_INT_T utils_axes_mask_value_to_face(AxesMaskValue v) {
    switch (v) {
        case AxesMaskX:
            return FACE_RIGHT;
        case AxesMaskNX:
            return FACE_LEFT;
        case AxesMaskY:
            return FACE_TOP;
        case AxesMaskNY:
            return FACE_DOWN;
        case AxesMaskZ:
            return FACE_FRONT;
        case AxesMaskNZ:
            return FACE_BACK;
        default:
            return FACE_NONE;
    }
}

uint8_t utils_axes_mask_swapped(uint8_t mask) {
    return 0 | ((mask & AxesMaskX) == AxesMaskX ? AxesMaskNX : 0) |
           ((mask & AxesMaskNX) == AxesMaskNX ? AxesMaskX : 0) |
           ((mask & AxesMaskY) == AxesMaskY ? AxesMaskNY : 0) |
           ((mask & AxesMaskNY) == AxesMaskNY ? AxesMaskY : 0) |
           ((mask & AxesMaskZ) == AxesMaskZ ? AxesMaskNZ : 0) |
           ((mask & AxesMaskNZ) == AxesMaskNZ ? AxesMaskZ : 0);
}

AxesMaskValue utils_axes_mask_value_swapped(AxesMaskValue v) {
    switch (v) {
        case AxesMaskX:
            return AxesMaskNX;
        case AxesMaskNX:
            return AxesMaskX;
        case AxesMaskY:
            return AxesMaskNY;
        case AxesMaskNY:
            return AxesMaskY;
        case AxesMaskZ:
            return AxesMaskNZ;
        case AxesMaskNZ:
            return AxesMaskZ;
        default:
            return AxesMaskNone;
    }
}

AxesMaskValue utils_axis_index_to_mask_value(AxisIndex idx) {
    switch (idx) {
        case AxisIndexX:
            return AxesMaskX;
        case AxisIndexNX:
            return AxesMaskNX;
        case AxisIndexY:
            return AxesMaskY;
        case AxisIndexNY:
            return AxesMaskNY;
        case AxisIndexZ:
            return AxesMaskZ;
        case AxisIndexNZ:
            return AxesMaskNZ;
        default:
            return AxesMaskX; // should not happen
    }
}

// STRINGS / STRING ARRAYS

char *_string_new_join(int nbArgs, ...) {

    va_list ap;
    size_t len = 0;

    if (nbArgs < 1)
        return NULL;

    // First, measure the total length required.
    va_start(ap, nbArgs);
    for (int i = 0; i < nbArgs; i++) {
        const char *s = va_arg(ap, char *);
        len += strlen(s);
    }
    va_end(ap);

    // Allocate return buffer.
    char *ret = (char *)malloc(len + 1);
    if (ret == NULL)
        return NULL;

    // Concatenate all the strings into the return buffer.
    char *dst = ret;
    va_start(ap, nbArgs);
    for (int i = 0; i < nbArgs; i++) {
        const char *src = va_arg(ap, char *);
        strcpy(dst, src);
        dst += strlen(src);
    }
    va_end(ap);

    ret[len] = '\0';

    return ret;
}

///
char *string_new_copy(const char *src) {
    if (src == NULL) {
        return NULL;
    }
    const size_t srcLen = strlen(src) + 1 /* null termination char */;
    char *buffer = (char *)malloc(sizeof(char) * srcLen);
    // make sure the buffer allocation succeeded
    if (buffer == NULL) {
        return NULL;
    }
    strcpy(buffer, src);
    return buffer;
}

char *string_new_substring(const char *start, const char *end) {
    if (start == NULL) {
        return NULL;
    }
    if (end == NULL) {
        return NULL;
    }

    size_t len = (size_t)(end - start);

    char *buffer = (char *)malloc(sizeof(char) * (len + 1)); //  + 1: null termination char */;
    if (buffer == NULL) {
        return NULL;
    }
    strncpy(buffer, start, len);
    buffer[len] = '\0';
    return buffer;
}

///
/// string_new_copy_with_limit
char *string_new_copy_with_limit(const char *src, const size_t len) {
    if (src == NULL) {
        return NULL;
    }

    size_t srcLen = strlen(src);
    if (srcLen > len) {
        srcLen = len;
    }

    char *buffer = (char *)malloc(sizeof(char) * (srcLen + 1)); //  + 1: null termination char */;
    strncpy(buffer, src, srcLen);
    buffer[srcLen] = '\0';
    return buffer;
}

///
stringArray_t *string_split(const char *path, const char *delimiters) {

    stringArray_t *arr = stringArray_new();

    const char *cursor = path;

    int i = 1; // there's at least one component

    size_t len, pos;

    while (true) {
        len = strlen(cursor);
        pos = strcspn(cursor, delimiters);
        if (pos == len) {
            break;
        } // not found
        if (pos > 0) {
            i++;
        } // do not consider empty components
        if (pos + 1 >= len) {
            break;
        } // ends with delimiter, stop here
        cursor += pos + 1;
    }

    // rewind
    cursor = path;

    while (true) {
        len = strlen(cursor);
        pos = strcspn(cursor, delimiters);
        if (pos == len) {
            break;
        }              // not found
        if (pos > 0) { // do not consider empty components
            stringArray_n_append(arr, cursor, pos);
        }
        if (pos + 1 >= len) {
            return arr;
        }                  // ends with delimiter, stop here
        cursor += pos + 1; // skip delimiter
    }

    // last component (the one after last delimiter)
    len = strlen(cursor);
    stringArray_n_append(arr, cursor, len);
    return arr;
}

struct _stringArray_t {
    char **strings;
    int length;
    char pad[4];
};

stringArray_t *stringArray_new(void) {
    stringArray_t *arr = (stringArray_t *)malloc(sizeof(stringArray_t));
    if (arr != NULL) {
        arr->strings = NULL;
        arr->length = 0;
    }
    return arr;
}

void stringArray_free(stringArray_t *arr) {
    if (arr != NULL) {
        for (int i = 0; i < arr->length; i++) {
            free(arr->strings[i]);
            arr->strings[i] = NULL;
        }
        free(arr->strings);
        arr->strings = NULL;
        arr->length = 0;
    }
    free(arr);
}

bool stringArray_n_append(stringArray_t *arr, const char *str, size_t length) {
    if (arr == NULL) {
        return false;
    }
    if (str == NULL) {
        return false;
    }
    arr->strings = (char **)realloc(arr->strings, sizeof(char *) * (size_t)(arr->length + 1));
    if (arr->strings == NULL) {
        return false;
    }
    arr->length += 1;
    arr->strings[arr->length - 1] = string_new_copy_with_limit(str, length);
    return true;
}

int stringArray_length(stringArray_t *arr) {
    if (arr == NULL) {
        return -1;
    }
    return arr->length;
}

const char *stringArray_get(const stringArray_t *arr, const int idx) {
    if (arr == NULL) {
        return NULL;
    }
    if (arr->length <= idx) {
        return NULL;
    }
    return arr->strings[idx];
}

char *utils_get_baked_fullname(const char *id, const char *itemFullname) {
    if (id == NULL || strlen(id) == 0) {
        return NULL;
    }

    char *bakedFullname = NULL;

    if (itemFullname != NULL && strlen(itemFullname) > 0) {
        stringArray_t *arr = string_split(itemFullname, ".");
        const int len = stringArray_length(arr);
        if (len == 2) { // itemFullname is of the form <username>.<file>
            const char *user = stringArray_get(arr, 0);
            const char *file = stringArray_get(arr, 1);
            bakedFullname = string_new_join(user, ".baked_", file, "_", id);
        } else {
            bakedFullname = string_new_join("baked_", itemFullname, "_", id);
        }
        stringArray_free(arr);
    } else {
        bakedFullname = string_new_join("baked_", id);
    }

    return bakedFullname;
}

void utils_rgba_to_uint8(uint32_t rgba, uint8_t *out) {
    *out = (uint8_t)(rgba & 0xff);
    *(out + 1) = (uint8_t)((rgba >> 8) & 0xff);
    *(out + 2) = (uint8_t)((rgba >> 16) & 0xff);
    *(out + 3) = (uint8_t)((rgba >> 24) & 0xff);
}

uint32_t utils_uint8_to_rgba(uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
    return (uint32_t)r + ((uint32_t)g << 8) + ((uint32_t)b << 16) + ((uint32_t)a << 24);
}

void utils_rgba_to_float(uint32_t rgba, float *out) {
    *out = (float)(rgba & 0xff) / 255.0f;
    *(out + 1) = (float)((rgba >> 8) & 0xff) / 255.0f;
    *(out + 2) = (float)((rgba >> 16) & 0xff) / 255.0f;
    *(out + 3) = (float)((rgba >> 24) & 0xff) / 255.0f;
}
