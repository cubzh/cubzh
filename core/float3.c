// -------------------------------------------------------------
//  Cubzh Core
//  float3.c
//  Created by Adrien Duermael on July 19, 2015.
// -------------------------------------------------------------

#include "float3.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "config.h"
#include "filo_list_float3.h"
#include "matrix4x4.h"
#include "quaternion.h"
#include "utils.h"

// =============================================================================
// MARK: - File Private -
// =============================================================================

// variables used within functions to avoid allocations
static float _length;
static float _f;
static float _x, _y, _z;

/// Utils to go from RGB to HSB and vice versa

typedef struct {
    float r; // a fraction between 0 and 1
    float g; // a fraction between 0 and 1
    float b; // a fraction between 0 and 1
} rgb;

typedef struct {
    float h; // angle in degrees
    float s; // a fraction between 0 and 1
    float v; // a fraction between 0 and 1
} hsv;

/*
static hsv rgb2hsv(rgb in);
static rgb hsv2rgb(hsv in);

hsv rgb2hsv(rgb in) {
    hsv out;
    float min, max, delta;

    min = in.r < in.g ? in.r : in.g;
    min = min  < in.b ? min  : in.b;

    max = in.r > in.g ? in.r : in.g;
    max = max  > in.b ? max  : in.b;

    out.v = max;                                // v
    delta = max - min;
    if (delta < 0.001f) {
        out.s = 0.0f;
        out.h = 0.0f; // undefined, maybe nan?
        return out;
    }

    if (max > 0.0f) { // NOTE: if Max is == 0, this divide would cause a crash
        out.s = (delta / max);                  // s

    } else {
        // if max is 0, then r = g = b = 0
        // s = 0, h is undefined but set to 0 in this case
        out.s = 0.0f;
        out.h = 0.0f;
        return out;
    }

    if (in.r >= max) {
        out.h = (in.g - in.b) / delta;            // between yellow & magenta
    } else {
        if (in.g >= max)
            out.h = 2.0f + (in.b - in.r) / delta; // between cyan & yellow

        else
            out.h = 4.0f + (in.r - in.g) / delta; // between magenta & cyan
    }
    out.h *= 60.0f;                               // degrees

    if (out.h < 0.0f)
        out.h += 360.0f;

    return out;
}

rgb hsv2rgb(hsv in) {
    float hh, p, q, t, ff;
    long i;
    rgb out;

    // gray color
    if(in.s <= 0.0f) {
        out.r = in.v;
        out.g = in.v;
        out.b = in.v;
        return out;
    }

    hh = in.h;
    if (hh >= 360.0f) hh = 0.0f;
    hh /= 60.0f;
    i = (long)hh;
    ff = hh - i;
    p = in.v * (1.0f - in.s);
    q = in.v * (1.0f - (in.s * ff));
    t = in.v * (1.0f - (in.s * (1.0f - ff)));

    switch(i) {
    case 0:
        out.r = in.v;
        out.g = t;
        out.b = p;
        break;
    case 1:
        out.r = q;
        out.g = in.v;
        out.b = p;
        break;
    case 2:
        out.r = p;
        out.g = in.v;
        out.b = t;
        break;
    case 3:
        out.r = p;
        out.g = q;
        out.b = in.v;
        break;
    case 4:
        out.r = t;
        out.g = p;
        out.b = in.v;
        break;
    case 5:
    default:
        out.r = in.v;
        out.g = p;
        out.b = q;
        break;
    }
    return out;
}*/

// =============================================================================
// MARK: - Exposed functions -
// =============================================================================

FiloListFloat3 *float3_pool(void) {
    static FiloListFloat3 p = {NULL, NULL, 10, 0};
    return &p;
}

float3 *float3_pool_pop(void) {
    float3 *f3 = NULL;
    filo_list_float3_pop(float3_pool(), &f3);
    return f3;
}

float3 *float3_pool_pop_and_set(const float x, const float y, const float z) {
    float3 *f3 = NULL;
    filo_list_float3_pop(float3_pool(), &f3);
    float3_set(f3, x, y, z);
    return f3;
}

float3 *float3_pool_pop_and_copy(const float3 *src) {
    if (src == NULL) {
        return NULL;
    }
    float3 *f3 = NULL;
    filo_list_float3_pop(float3_pool(), &f3);
    float3_copy(f3, src);
    return f3;
}

void float3_pool_recycle(float3 *f3) {
    filo_list_float3_recycle(float3_pool(), f3);
}

/// allocates a float3 structure
float3 *float3_new(const float x, const float y, const float z) {
    float3 *f = (float3 *)malloc(sizeof(float3));
    if (f != NULL) {
        f->x = x;
        f->y = y;
        f->z = z;
    }
    return f;
}

float3 *float3_new_zero(void) {
    return float3_new(0.0f, 0.0f, 0.0f);
}

float3 *float3_new_one(void) {
    return float3_new(1.0f, 1.0f, 1.0f);
}

/// allocates a float3 structure
float3 *float3_new_copy(const float3 *f) {
    if (f == NULL) {
        return NULL;
    }
    return float3_new(f->x, f->y, f->z);
}

/// free a float3 structure
void float3_free(float3 *f) {
    free(f);
}

/// set float3 value to another float3 value
void float3_copy(float3 *dest, const float3 *src) {
    dest->x = src->x;
    dest->y = src->y;
    dest->z = src->z;
}

/// f1 = f1 X f2 (f1 is modified)
void float3_cross_product(float3 *f1, const float3 *f2) {
    _x = f1->y * f2->z - f1->z * f2->y;
    _y = f1->z * f2->x - f1->x * f2->z;
    _z = f1->x * f2->y - f1->y * f2->x;
    f1->x = _x;
    f1->y = _y;
    f1->z = _z;
}

void float3_cross_product2(const float3 *f1, float3 *f2) {
    _x = f1->y * f2->z - f1->z * f2->y;
    _y = f1->z * f2->x - f1->x * f2->z;
    _z = f1->x * f2->y - f1->y * f2->x;
    f2->x = _x;
    f2->y = _y;
    f2->z = _z;
}

float3 float3_cross_product3(const float3 *f1, const float3 *f2) {
    float3 result;
    result.x = f1->y * f2->z - f1->z * f2->y;
    result.y = f1->z * f2->x - f1->x * f2->z;
    result.z = f1->x * f2->y - f1->y * f2->x;
    return result;
}

/// f1 • f2 dot product
float float3_dot_product(const float3 *const f1, const float3 *const f2) {
    return f1->x * f2->x + f1->y * f2->y + f1->z * f2->z;
}

float float3_sqr_length(const float3 *f) {
    return f->x * f->x + f->y * f->y + f->z * f->z;
}

float float3_length(const float3 *f) {
    return sqrtf(f->x * f->x + f->y * f->y + f->z * f->z);
}

float float3_distance(const float3 *f1, const float3 *f2) {
    const float dx = f2->x - f1->x;
    const float dy = f2->y - f1->y;
    const float dz = f2->z - f1->z;
    return sqrtf(dx * dx + dy * dy + dz * dz);
}

/// normalizes a float3
void float3_normalize(float3 *const f) {
    _length = float3_length(f);
    if (_length != 0.0f) {
        f->x /= _length;
        f->y /= _length;
        f->z /= _length;
    }
}

float float3_mmax(const float3 *f) {
    const float xy = f->x > f->y ? f->x : f->y;
    return xy > f->z ? xy : f->z;
}

float3 float3_mmax2(const float3 *f1, const float3 *f2) {
    return (float3){maximum(f1->x, f2->x), maximum(f1->y, f2->y), maximum(f1->z, f2->z)};
}

float float3_mmin(const float3 *f) {
    const float xy = f->x < f->y ? f->x : f->y;
    return xy < f->z ? xy : f->z;
}

float3 float3_mmin2(const float3 *f1, const float3 *f2) {
    return (float3){minimum(f1->x, f2->x), minimum(f1->y, f2->y), minimum(f1->z, f2->z)};
}

void float3_set_norm(float3 *f, float n) {
    _length = float3_length(f);
    if (_length == 0.0f) {
        return;
    }
    _f = n / _length;
    f->x = f->x * _f;
    f->y = f->y * _f;
    f->z = f->z * _f;
}

/// sums two float3 (first argument is modified)
void float3_op_add(float3 *f1, const float3 *f2) {
    f1->x += f2->x;
    f1->y += f2->y;
    f1->z += f2->z;
}

void float3_op_add_scalar(float3 *f3, const float f) {
    f3->x += f;
    f3->y += f;
    f3->z += f;
}

/// substract f2 from f1 (first argument is modified)
void float3_op_substract(float3 *f1, const float3 *f2) {
    f1->x -= f2->x;
    f1->y -= f2->y;
    f1->z -= f2->z;
}

void float3_op_substract_scalar(float3 *f3, const float f) {
    f3->x -= f;
    f3->y -= f;
    f3->z -= f;
}

void float3_op_mult(float3 *f1, const float3 *f2) {
    f1->x *= f2->x;
    f1->y *= f2->y;
    f1->z *= f2->z;
}

/// multiply float3 by a scale factor
void float3_op_scale(float3 *f, const float scale) {
    f->x *= scale;
    f->y *= scale;
    f->z *= scale;
}

void float3_op_unscale(float3 *f, const float scale) {
    f->x /= scale;
    f->y /= scale;
    f->z /= scale;
}

void float3_op_clamp(float3 *f, const float min, const float max) {
    f->x = CLAMP(f->x, min, max);
    f->y = CLAMP(f->y, min, max);
    f->z = CLAMP(f->z, min, max);
}

/// rotates a vector by given euler rotation
void float3_rotate(float3 *f, const float rx, const float ry, const float rz) {
    Quaternion q;
    euler_to_quaternion(rx, ry, rz, &q);
    quaternion_rotate_vector(&q, f);
}

/// rotates a vector by given axis angle
void float3_rotate_around_axis(float3 *f, float3 *axis, const float angle) {
    Quaternion q;
    axis_angle_to_quaternion(axis, angle, &q);
    quaternion_rotate_vector(&q, f);
}

/// changes value of a float3
void float3_set(float3 *f, const float x, const float y, const float z) {
    f->x = x;
    f->y = y;
    f->z = z;
}

void float3_set_zero(float3 *f) {
    float3_set(f, 0.0f, 0.0f, 0.0f);
}

void float3_set_one(float3 *f) {
    float3_set(f, 1.0f, 1.0f, 1.0f);
}

/// Returns result of negated multiply-sub operation -(_a * _b - _c).
/// Borrowed from bgfx
float _nms(float _a, float _b, float _c) {
    return _c - _a * _b;
}

/// Returns result of multipla and add (_a * _b + _c).
/// Borrowed from bgfx
float _mad(float _a, float _b, float _c) {
    return _a * _b + _c;
}

/// Returns linear interpolation between two values _a and _b.
/// Borrowed from bgfx
float _lerp(float _a, float _b, float _t) {
    // Reference(s):
    // - Linear interpolation past, present and future
    //   https://web.archive.org/web/20200404165201/https://fgiesen.wordpress.com/2012/08/15/linear-interpolation-past-present-and-future/
    //
    return _mad(_t, _b, _nms(_t, _a, _a));
}

void float3_lerp(const float3 *a, const float3 *b, const float t, float3 *res) {
    res->x = _lerp(a->x, b->x, t);
    res->y = _lerp(a->y, b->y, t);
    res->z = _lerp(a->z, b->z, t);
}

// void float3_hsv_lerp(const float3 *a, const float3 *b, const float t, float3 *res) {
//     rgb aRGB;
//     aRGB.r = a->x;
//     aRGB.g = a->y;
//     aRGB.b = a->z;
//     hsv aHSV = rgb2hsv(aRGB);
//     rgb bRGB;
//     bRGB.r = b->x;
//     bRGB.g = b->y;
//     bRGB.b = b->z;
//     hsv bHSV = rgb2hsv(bRGB);
//     hsv result;
//
//     //if (aHSV.h > bHSV.h)
//     //    result.h = bHSV.h + (aHSV.h - bHSV.h) * t;
//     //else
//     //    result.h = aHSV.h + (bHSV.h - aHSV.h) * t;
//
//     //if (aHSV.s > bHSV.s)
//     //    result.s = bHSV.s + (aHSV.s - bHSV.s) * t;
//     //else
//     //    result.s = aHSV.s + (bHSV.s - aHSV.s) * t;
//
//     //if (aHSV.v > bHSV.v)
//     //    result.v = bHSV.v + (aHSV.v - bHSV.v) * t;
//     //else
//     //    result.v = aHSV.v + (bHSV.v - aHSV.v) * t;
//
//     result.h = _lerp(aHSV.h, bHSV.h, t);
//     result.s = _lerp(aHSV.s, bHSV.s, t);
//     result.v = _lerp(aHSV.v, bHSV.v, t);
//
//     rgb resultRGB = hsv2rgb(result);
//     res->x = resultRGB.r;
//     res->y = resultRGB.g;
//     res->z = resultRGB.b;
// }

bool float3_isEqual(const float3 *f3_1, const float3 *f3_2, const float epsilon) {
    return float_isEqual(f3_1->x, f3_2->x, epsilon) && float_isEqual(f3_1->y, f3_2->y, epsilon) &&
           float_isEqual(f3_1->z, f3_2->z, epsilon);
}

bool float3_isZero(const float3 *f3, const float epsilon) {
    return float_isZero(f3->x, epsilon) && float_isZero(f3->y, epsilon) &&
           float_isZero(f3->z, epsilon);
}

bool float3_is_valid(const float3 *f3) {
    return float_is_valid(f3->x) && float_is_valid(f3->y) && float_is_valid(f3->z);
}
