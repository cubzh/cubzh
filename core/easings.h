// -------------------------------------------------------------
//  Cubzh Core
//  easings.h
//  Created by Arthur Cormerais on February 11, 2021.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef float (*pointer_easing_func)(float v);

/// You may check this visual reference for the effect of each function on the animation curve:
/// https://easings.net/ Eg. a bounce animation on a transform could be done w/ just 2 keyframes and
/// a parametric bounce easing

float easings_quadratic_in(float v);
float easings_quadratic_out(float v);
float easings_quadratic_inout(float v);

float easings_cubic_in(float v);
float easings_cubic_out(float v);
float easings_cubic_inout(float v);

float easings_exponential_in(float v);
float easings_exponential_out(float v);
float easings_exponential_inout(float v);

float easings_circular_in(float v);
float easings_circular_out(float v);
float easings_circular_inout(float v);

float easings_bounce_in(float v);
float easings_bounce_out(float v);
float easings_bounce_inout(float v);
float easings_parametric_bounce_in(float v, float amp, float speed);
float easings_parametric_bounce_out(float v, float amp, float speed);
float easings_parametric_bounce_inout(float v, float amp, float speed);

#ifdef __cplusplus
} // extern "C"
#endif
