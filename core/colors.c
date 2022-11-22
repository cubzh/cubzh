// -------------------------------------------------------------
//  Cubzh Core
//  colors.c
//  Created by Gaetan de Villele on June 25, 2016.
// -------------------------------------------------------------

#include "colors.h"
#include <math.h>

// --------------------------------------------------
//
// MARK: - color formats functions -
//
// --------------------------------------------------

rgb hsv2rgb(hsv in) {
    double hh, p, q, t, ff;
    long i;
    rgb out;

    if (in.s <= 0.0) { // < is bogus, just shuts up warnings
        out.r = in.v;
        out.g = in.v;
        out.b = in.v;
        return out;
    }
    hh = in.h;
    if (hh >= 360.0)
        hh = 0.0;
    hh /= 60.0;
    i = (long)(hh);
    ff = hh - i;
    p = in.v * (1.0 - in.s);
    q = in.v * (1.0 - (in.s * ff));
    t = in.v * (1.0 - (in.s * (1.0 - ff)));

    switch (i) {
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
}

double sRGBCompoundingValue(double value) {
    // See http://www.brucelindbloom.com/Eqn_RGB_to_XYZ.html for companding process

    if (value <= 0.04045) {
        return value / 12.92;
    } else {
        return pow((value + 0.055) / 1.055, 2.4);
    }
}

double LabFunction(double value) {
    // See http://www.brucelindbloom.com/Eqn_XYZ_to_Lab.html for Function f and constants below

    const double epsilon = 216.0 / 24389.0; // Intent of the CIE Standard
    const double kappa = 24389.0 / 27.0;    // Intent of the CIE Standard

    if (value > epsilon) {
        return pow(value, 1.0 / 3.0); // Cube Root, can be replaced by cbrt(value, 3)
    } else {
        return (kappa * value + 16.0) / 116.0;
    }
}

xyz RGB2XYZ(rgb color) {
    // Compute the inverse sRGB companding and multiply them by 100
    color.r = sRGBCompoundingValue(color.r);
    color.g = sRGBCompoundingValue(color.g);
    color.b = sRGBCompoundingValue(color.b);

    // Compute XYZ values using the RGB/XYZ Matrice
    // Using Matrice values of RGB to XYZ
    // Reference White : D65
    // See http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
    xyz out;
    out.x = color.r * 0.4124564 + color.g * 0.3575761 + color.b * 0.1804375;
    out.y = color.r * 0.2126729 + color.g * 0.7151522 + color.b * 0.0721750;
    out.z = color.r * 0.0193339 + color.g * 0.1191920 + color.b * 0.9503041;

    return out;
}

Lab XYZ2Lab(xyz XYZColor) {
    // Convert XYZ to xr yr zr with Reference White D65 (Xr = 95.047, Yr = 100.000, Zr = 108.883)
    // between 0 and 1 See http://www.brucelindbloom.com/Eqn_XYZ_to_Lab.html
    double xr = XYZColor.x / 0.95047;
    double yr = XYZColor.y / 1.00000;
    double zr = XYZColor.z / 1.08883;

    // Compute fx, fy and fz
    double fx = LabFunction(xr);
    double fy = LabFunction(yr);
    double fz = LabFunction(zr);

    // Compute Lab color
    Lab out;
    out.L = (116.0 * fy) - 16.0;
    out.a = 500.0 * (fx - fy);
    out.b = 200.0 * (fy - fz);
    return out;
}

float CIEDE2000(Lab c1, Lab c2) {
    // /!\ WARNING c1 is reference color and c2 is sample color
    // See http://www.brucelindbloom.com/Eqn_DeltaE_CIE2000.html

    double L_bar_prime = (c1.L + c2.L) / 2.0;

    double C_1 = sqrt(pow(c1.a, 2.0) + pow(c1.b, 2.0));
    double C_2 = sqrt(pow(c2.a, 2.0) + pow(c2.b, 2.0));

    double C_bar = (C_1 + C_2) / 2.0;

    double G = 0.5 * (1 - sqrt(pow(C_bar, 7.0) / (pow(C_bar, 7.0) + pow(25.0, 7.0))));

    double a_1_prime = c1.a * (1.0 + G);
    double a_2_prime = c2.a * (1.0 + G);

    double C_1_prime = sqrt(pow(a_1_prime, 2.0) + pow(c1.b, 2.0));
    double C_2_prime = sqrt(pow(a_2_prime, 2.0) + pow(c2.b, 2.0));

    double C_bar_prime = (C_1_prime + C_2_prime) / 2.0;

    double h_1_prime = atan2(c1.b, a_1_prime) * 180.0 /
                       PI; // Multiply by 180 and divide by pi to convert radian to degree
    if (h_1_prime < 0.0) {
        h_1_prime += 360.0;
    }

    double h_2_prime = atan2(c2.b, a_2_prime) * 180.0 /
                       PI; // Multiply by 180 and divide by pi to convert radian to degree
    if (h_2_prime < 0.0) {
        h_2_prime += 360.0;
    }

    double H_angle_prime = fabs(h_1_prime - h_2_prime) > 180.0 ? (h_1_prime + h_2_prime + 360.0) / 2.0
                                                               : (h_1_prime + h_2_prime) / 2.0;

    double T = 1 - 0.17 * cos((H_angle_prime - 30.0) / 180.0 * PI) +
               0.24 * cos((2 * H_angle_prime) / 180.0 * PI) +
               0.32 * cos((3 * H_angle_prime + 6.0) / 180.0 * PI) -
               0.20 * cos((4 * H_angle_prime - 63.0) / 180.0 *
                          PI); // Divide by 180 and multiply by pi to convert degree to radian

    double delta_h_prime;

    if (fabs(h_2_prime - h_1_prime) < 180.0) {
        delta_h_prime = h_2_prime - h_1_prime;
    } else if (h_2_prime <= h_1_prime) {
        delta_h_prime = h_2_prime - h_1_prime + 360.0;
    } else {
        delta_h_prime = h_2_prime - h_1_prime - 360.0;
    }

    double delta_L_prime = c2.L - c1.L;

    double delta_C_prime = C_2_prime - C_1_prime;

    double delta_H_prime = 2.0 * sqrt(C_1_prime * C_2_prime) *
                           sin((delta_h_prime / 2.0) / 180.0 *
                               PI); // Divide by 180 and multiply by pi to convert degree to radian

    double S_L = 1.0 + ((0.015 * pow(L_bar_prime - 50.0, 2.0)) / sqrt(20.0 + pow(L_bar_prime - 50.0, 2.0)));

    double S_C = 1 + (0.045 * C_bar_prime);

    double S_H = 1 + (0.015 * C_bar_prime * T);

    double delta_theta = 30.0 * exp(0.0 - pow((H_angle_prime - 275.0) / 25.0, 2.0));

    double R_C = sqrt((pow(C_bar_prime, 7.0)) / (pow(C_bar_prime, 7.0) + pow(25.0, 7.0)));

    double R_T = -2.0 * R_C *
                 sin(2.0 * delta_theta / 180.0 *
                     PI); // Divide by 180 and multiply by pi to convert degree to radian

    double K_L = 1.0;
    double K_C = 1.0;
    double K_H = 1.0;

    double Delta_E = sqrt(((delta_L_prime) / (K_L * S_L)) * ((delta_L_prime) / (K_L * S_L)) +
                          ((delta_C_prime) / (K_C * S_C)) * ((delta_C_prime) / (K_C * S_C)) +
                          ((delta_H_prime) / (K_H * S_H)) * ((delta_H_prime) / (K_H * S_H)) +
                          (((delta_C_prime) / (K_C * S_C)) * ((delta_H_prime) / (K_H * S_H)) * R_T));

    return Delta_E;
}

void RGB2YIQ(float3 *yiq, RGBAColor rgb) {
    float r = (float)rgb.r;
    float g = (float)rgb.g;
    float b = (float)rgb.b;
    yiq->x = .299f * r + .587f * g + .114f * b;
    yiq->y = .595716f * r - .274453f * g - .321263f * b;
    yiq->z = .211456f * r - .522591f * g + .311135f * b;
}

RGBAColor YIQ2RGB(float3 *yiq) {
    RGBAColor rgb;
    rgb.r = (uint8_t)(CLAMP(1.0f * yiq->x + .9563f * yiq->y + .6210f * yiq->z, 0.0f, 255.0f));
    rgb.g = (uint8_t)(CLAMP(1.0f * yiq->x - .2721f * yiq->y - .6474f * yiq->z, 0.0f, 255.0f));
    rgb.b = (uint8_t)(CLAMP(1.0f * yiq->x - 1.1070f * yiq->y + 1.7046f * yiq->z, 0.0f, 255.0f));
    rgb.a = 255;
    return rgb;
}

// --------------------------------------------------
//
// MARK: - higher level color structures functions -
//
// --------------------------------------------------

uint32_t color_to_uint32(const RGBAColor *c) {
    return ((uint32_t)(c->r)) + (((uint32_t)(c->g)) << 8) + (((uint32_t)(c->b)) << 16) +
           (((uint32_t)(c->a)) << 24);
}

RGBAColor uint32_to_color(uint32_t rgba) {
    RGBAColor result = {(uint8_t)rgba, (uint8_t)(rgba >> 8), (uint8_t)(rgba >> 16), (uint8_t)(rgba >> 24)};
    return result;
}

bool colors_are_equal(const RGBAColor *c1, const RGBAColor *c2) {
    return c1->r == c2->r && c1->g == c2->g && c1->b == c2->b && c1->a == c2->a;
}

bool color_is_opaque(const RGBAColor *c) {
    return c->a == 255;
}

RGBAColor color_compute_complementary(RGBAColor c) {
    float3 f;
    RGB2YIQ(&f, c);
    float angle = atan2f(f.z, f.y);
    float len = sqrtf(f.y * f.y + f.z * f.z);

#if AO_COLOR_HUE_CLAMP_TARGET
    if (angle >= AO_COLOR_HUE_THRESHOLD_TARGET) {
        angle = fmaxf(angle - AO_COLOR_HUE_STEP, AO_COLOR_HUE_THRESHOLD_TARGET);
    } else if (angle <= AO_COLOR_HUE_THRESHOLD_DIR) {
        angle = fmaxf(angle - AO_COLOR_HUE_STEP, -2.0f * PI_F + AO_COLOR_HUE_THRESHOLD_TARGET);
    } else {
        angle = fminf(angle + AO_COLOR_HUE_STEP, AO_COLOR_HUE_THRESHOLD_TARGET);
    }
#else
    angle += (angle >= AO_COLOR_HUE_THRESHOLD_TARGET || angle <= AO_COLOR_HUE_THRESHOLD_DIR)
                 ? -AO_COLOR_HUE_STEP
                 : AO_COLOR_HUE_STEP;
#endif

    f.y = len * cosf(angle);
    f.z = len * sinf(angle);
    return YIQ2RGB(&f);
}

/// Performs a fixed rotation by provided hue in radians,
/// used to validate palette_compute_complementary_color results
/// full transformation here: https://beesbuzz.biz/code/16-hsv-color-transforms
RGBAColor _rotateHue(RGBAColor rgb, float hue) {
    float vsu = cosf(hue);
    float vsw = sinf(hue);

    RGBAColor ret;
    ret.r = CLAMP((.299f + .701f * vsu + .168f * vsw) * rgb.r + (.587f - .587f * vsu + .330f * vsw) * rgb.g +
                      (.114f - .114f * vsu - .497f * vsw) * rgb.b,
                  0.0f,
                  255.0f);
    ret.g = CLAMP((.299f - .299f * vsu - .328f * vsw) * rgb.r + (.587f + .413f * vsu + .035f * vsw) * rgb.g +
                      (.114f - .114f * vsu + .292f * vsw) * rgb.b,
                  0.0f,
                  255.0f);
    ret.b = CLAMP((.299f - .300f * vsu + 1.25f * vsw) * rgb.r + (.587f - .588f * vsu - 1.05f * vsw) * rgb.g +
                      (.114f + .886f * vsu - .203f * vsw) * rgb.b,
                  0.0f,
                  255.0f);
    return ret;
}
