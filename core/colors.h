// -------------------------------------------------------------
//  Cubzh Core
//  colors.h
//  Created by Gaetan de Villele on June 25, 2016.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>

#include "config.h"
#include "float3.h"

// 16,777,216 colors with 256 alpha levels per color
// 4,294,967,296 combinaisons
typedef struct RGBAColor {
    uint8_t r;
    uint8_t g;
    uint8_t b;
    uint8_t a;
} RGBAColor;

static const RGBAColor RGBAColor_clear = {0, 0, 0, 0};

typedef struct {
    double r; // a fraction between 0 and 1
    double g; // a fraction between 0 and 1
    double b; // a fraction between 0 and 1
} rgb;

typedef struct {
    double h;
    double s;
    double v;
} hsv;

typedef struct {
    double x;
    double y;
    double z;
} xyz;

typedef struct {
    double L;
    double a;
    double b;
} Lab;

// color conversions
hsv rgb2hsv(rgb in);
rgb hsv2rgb(hsv in);
double sRGBCompoundingValue(double value);
double LabFunction(double value);
xyz RGB2XYZ(rgb color);
Lab XYZ2Lab(xyz XYZColor);
float CIEDE2000(Lab c1, Lab c2);
void RGB2YIQ(float3 *yiq, RGBAColor rgbIn);
RGBAColor YIQ2RGB(float3 *yiq);

uint32_t color_to_uint32(const RGBAColor *c);
RGBAColor uint32_to_color(uint32_t rgba);
bool colors_are_equal(const RGBAColor *c1, const RGBAColor *c2);
bool color_is_opaque(const RGBAColor *c);
RGBAColor color_compute_complementary(RGBAColor c);

#ifdef __cplusplus
} // extern "C"
#endif
