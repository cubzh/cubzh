// -------------------------------------------------------------
//  Cubzh Core
//  easings.c
//  Created by Arthur Cormerais on February 11, 2021.
// -------------------------------------------------------------

#include "easings.h"

#include <math.h>

#include "utils.h"

float easings_quadratic_in(float v) {
    return v * v;
}

float easings_quadratic_out(float v) {
    return 1 - (1 - v) * (1 - v);
}

float easings_quadratic_inout(float v) {
    return v < 0.5f ? 2 * v * v : 1 - powf(-2 * v + 2, 2) / 2;
}

float easings_cubic_in(float v) {
    return v * v * v;
}

float easings_cubic_out(float v) {
    return 1 - powf(1 - v, 3);
}

float easings_cubic_inout(float v) {
    return v < 0.5f ? 4 * v * v * v : 1 - powf(-2 * v + 2, 3) / 2;
}

float easings_exponential_in(float v) {
    return float_isZero(v, EPSILON_ZERO) ? 0.0f : powf(2, 10 * (v - 1));
}

float easings_exponential_out(float v) {
    return float_isEqual(v, 1.0f, EPSILON_ZERO) ? 1 : 1 - powf(2, -10 * v);
}

float easings_exponential_inout(float v) {
    return float_isZero(v, EPSILON_ZERO)          ? 0
           : float_isEqual(v, 1.0f, EPSILON_ZERO) ? 1
           : v < 0.5f                             ? powf(2, 20 * v - 10) / 2
                                                  : (2 - powf(2, -20 * v + 10)) / 2;
}

float easings_circular_in(float v) {
    return 1 - sqrtf(1 - v * v);
}

float easings_circular_out(float v) {
    return sqrtf(1 - powf(v - 1, 2));
}

float easings_circular_inout(float v) {
    return v < 0.5f ? (1 - sqrtf(1 - powf(2 * v, 2))) / 2 : (sqrtf(1 - powf(-2 * v + 2, 2)) + 1) / 2;
}

float easings_bounce_in(float v) {
    return easings_parametric_bounce_in(v, 7.5625f, 2.75f);
}

float easings_bounce_out(float v) {
    return easings_parametric_bounce_out(v, 7.5625f, 2.75f);
}

float easings_bounce_inout(float v) {
    return easings_parametric_bounce_inout(v, 7.5625f, 2.75f);
}

float easings_parametric_bounce_in(float v, float amp, float speed) {
    return 1 - easings_parametric_bounce_out(1 - v, amp, speed);
}

float easings_parametric_bounce_out(float v, float amp, float speed) {
    if (v < 1 / speed) {
        return amp * v * v;
    } else if (v < 2 / speed) {
        const float _v = v - 1.5f / speed;
        return amp * _v * _v + 0.75f;
    } else if (v < 2.5f / speed) {
        const float _v = v - 2.25f / speed;
        return amp * _v * _v + 0.9375f;
    } else {
        const float _v = v - 2.625f / speed;
        return amp * _v * _v + 0.984375f;
    }
}

float easings_parametric_bounce_inout(float v, float amp, float speed) {
    return v < 0.5f ? (1 - easings_parametric_bounce_out(1 - 2 * v, amp, speed)) / 2
                    : (1 + easings_parametric_bounce_out(2 * v - 1, amp, speed)) / 2;
}
