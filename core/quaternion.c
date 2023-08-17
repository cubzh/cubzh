// -------------------------------------------------------------
//  Cubzh Core
//  quaternion.c
//  Created by Arthur Cormerais on january 27, 2021.
// -------------------------------------------------------------

#include "quaternion.h"

#include <math.h>
#include <stdbool.h>
#include <stdlib.h>

#include "config.h"
#include "float3.h"
#include "utils.h"

/// Internal epsilon for quaternion normalization, best leave it as low as possible to remove
/// imprecision every chance we get, however it could be slightly increased eg. 1e-8f or 1e-7f
/// within floating point imprecision, to reduce the number of normalize calls
#define QUATERNION_NORMALIZE_EPSILON 0.0f

Quaternion *quaternion_new(const float x,
                           const float y,
                           const float z,
                           const float w,
                           const bool normalized) {
    Quaternion *q = (Quaternion *)malloc(sizeof(Quaternion));
    q->x = x;
    q->y = y;
    q->z = z;
    q->w = w;
    q->normalized = normalized;
    return q;
}

Quaternion *quaternion_new_identity(void) {
    return quaternion_new(0.0f, 0.0f, 0.0f, 1.0f, true);
}

void quaternion_free(Quaternion *q) {
    free(q);
}

void quaternion_set(Quaternion *q1, const Quaternion *q2) {
    q1->x = q2->x;
    q1->y = q2->y;
    q1->z = q2->z;
    q1->w = q2->w;
    q1->normalized = q2->normalized;
}

void quaternion_set_identity(Quaternion *q) {
    q->x = 0.0f;
    q->y = 0.0f;
    q->z = 0.0f;
    q->w = 1.0f;
    q->normalized = true;
}

float quaternion_magnitude(Quaternion *q) {
    return sqrtf(q->x * q->x + q->y * q->y + q->z * q->z + q->w * q->w);
}

float quaternion_square_magnitude(Quaternion *q) {
    return q->x * q->x + q->y * q->y + q->z * q->z + q->w * q->w;
}

float quaternion_angle(Quaternion *q) {
    quaternion_op_normalize(q);
    return 2.0f * acosf(q->w);
    // The following may be more robust but more expensive:
    // return 2.0f * atan2f(sqrtf(q->x * q->x + q->y * q->y + q->z * q->z), q->w);
}

bool quaternion_is_zero(Quaternion *q, float epsilon) {
    quaternion_op_normalize(q);
    return float_isEqual(q->w, 1.0f, epsilon);
}

bool quaternion_is_normalized(Quaternion *q, float epsilon) {
    return float_isEqual(quaternion_square_magnitude(q), 1.0f, epsilon);
}

bool quaternion_is_equal(Quaternion *q1, Quaternion *q2, float epsilon) {
    const float angle = quaternion_angle_between(q1, q2);
    return float_isZero(angle, epsilon) || float_isEqual(angle, PI2_F, epsilon);
}

// MARK: - Operations -

Quaternion *quaternion_op_scale(Quaternion *q, float f) {
    q->x *= f;
    q->y *= f;
    q->z *= f;
    q->w *= f;
    return q;
}

Quaternion *quaternion_op_unscale(Quaternion *q, float f) {
    q->x /= f;
    q->y /= f;
    q->z /= f;
    q->w /= f;
    return q;
}

Quaternion *quaternion_op_conjugate(Quaternion *q) {
    q->x = -q->x;
    q->y = -q->y;
    q->z = -q->z;
    return q;
}

/// Most operations work on normalized quaternions, we need to make this as cheap as possible
Quaternion *quaternion_op_normalize(Quaternion *q) {
    if (q->normalized) {
        return q;
    } else {
        q->normalized = true;
        const float sqm = quaternion_square_magnitude(q);
        if (float_isEqual(sqm, 1.0f, QUATERNION_NORMALIZE_EPSILON)) {
            return q;
        } else {
            return quaternion_op_unscale(q, sqrtf(sqm));
        }
    }
}

Quaternion *quaternion_op_inverse(Quaternion *q) {
    return quaternion_op_conjugate(quaternion_op_normalize(q));
}

Quaternion quaternion_op_mult(const Quaternion *q1, const Quaternion *q2) {
    Quaternion q;
    q.x = q1->w * q2->x + q1->x * q2->w + q1->y * q2->z - q1->z * q2->y;
    q.y = q1->w * q2->y + q1->y * q2->w + q1->z * q2->x - q1->x * q2->z;
    q.z = q1->w * q2->z + q1->z * q2->w + q1->x * q2->y - q1->y * q2->x;
    q.w = q1->w * q2->w - q1->x * q2->x - q1->y * q2->y - q1->z * q2->z;
    q.normalized = false;
    return q;
}

Quaternion *quaternion_op_mult_left(Quaternion *q1, const Quaternion *q2) {
    Quaternion q = quaternion_op_mult(q1, q2);
    quaternion_set(q1, &q);
    return q1;
}

Quaternion *quaternion_op_mult_right(const Quaternion *q1, Quaternion *q2) {
    Quaternion q = quaternion_op_mult(q1, q2);
    quaternion_set(q2, &q);
    return q2;
}

Quaternion *quaternion_op_lerp(const Quaternion *from,
                               const Quaternion *to,
                               Quaternion *lerped,
                               const float t) {
    const float v = CLAMP01(t);
    lerped->x = LERP(from->x, to->x, v);
    lerped->y = LERP(from->y, to->y, v);
    lerped->z = LERP(from->z, to->z, v);
    lerped->w = LERP(from->w, to->w, v);
    lerped->normalized = false;
    return lerped;
}

Quaternion *quaternion_op_slerp(const Quaternion *from,
                                const Quaternion *to,
                                Quaternion *lerped,
                                const float t) {

    float d = quaternion_op_dot(from, to); // cos(angle)

    // from/to are more than 90° apart, invert one to reduce spinning
    Quaternion _to = *to;
    if (d < 0.0f) {
        d = -d;
        quaternion_op_scale(&_to, -1.0f);
    }

    // use linear interpolation for small angles
    if (fabsf(d) >= 0.95f) {
        quaternion_op_lerp(from, &_to, lerped, t);
    } else {
        const float v = CLAMP01(t);
        const float angle = acosf(d);
        const float sina = sinf(angle);

        // use linear interpolation to avoid anomaly, from/to are 180° apart so shortest path is
        // undefined
        if (fabsf(sina) < EPSILON_ZERO_TRANSFORM_RAD) {
            quaternion_op_lerp(from, &_to, lerped, t);
        } else {
            const float div = 1.0f / sina;
            const float sinav = sinf(angle * v);
            const float sinaomv = sinf(angle * (1.0f - v));
            lerped->x = (from->x * sinaomv + _to.x * sinav) * div;
            lerped->y = (from->y * sinaomv + _to.y * sinav) * div;
            lerped->z = (from->z * sinaomv + _to.z * sinav) * div;
            lerped->w = (from->w * sinaomv + _to.w * sinav) * div;
            lerped->normalized = false;
        }
    }

    return lerped;
}

float quaternion_op_dot(const Quaternion *q1, const Quaternion *q2) {
    return q1->w * q2->w + q1->x * q2->x + q1->y * q2->y + q1->z * q2->z;
}

// MARK: - Conversions -

/// Ref: http://www.opengl-tutorial.org/assets/faq_quaternions/index.html#Q54
/// For rotation matrix conversion, handedness & axes convention matters,
/// in order to adapt the formula, I swapped the axes as follows:
///    (-z, -x, -y) <- what we get w/ formula from ref
///    (x, y, z) <- what we want
void quaternion_to_rotation_matrix(Quaternion *q, Matrix4x4 *mtx) {
    quaternion_op_normalize(q);

    const float xx = q->y * q->y;
    const float xy = q->y * q->z;
    const float xz = q->y * q->x;
    const float xw = -q->y * q->w;

    const float yy = q->z * q->z;
    const float yz = q->z * q->x;
    const float yw = -q->z * q->w;

    const float zz = q->x * q->x;
    const float zw = -q->x * q->w;

    mtx->x1y1 = 1.0f - 2.0f * (yy + zz);
    mtx->x1y2 = 2.0f * (xy - zw);
    mtx->x1y3 = 2.0f * (xz + yw);

    mtx->x2y1 = 2.0f * (xy + zw);
    mtx->x2y2 = 1.0f - 2.0f * (xx + zz);
    mtx->x2y3 = 2.0f * (yz - xw);

    mtx->x3y1 = 2.0f * (xz - yw);
    mtx->x3y2 = 2.0f * (yz + xw);
    mtx->x3y3 = 1.0f - 2.0f * (xx + yy);

    mtx->x1y4 = mtx->x2y4 = mtx->x3y4 = 0.0f;
    mtx->x4y1 = mtx->x4y2 = mtx->x4y3 = 0.0f;
    mtx->x4y4 = 1.0f;
}

/// Ref: http://www.opengl-tutorial.org/assets/faq_quaternions/index.html#Q55
/// Adapted this function axes as well, see notes above quaternion_to_rotation_matrix
void rotation_matrix_to_quaternion(const Matrix4x4 *mtx, Quaternion *q) {
    const float t = matrix4x4_get_trace(mtx);
    float x, y, z, w;
    if (t > EPSILON_ZERO) {
        const float s = sqrtf(t) * 2.0f;
        x = (mtx->x3y2 - mtx->x2y3) / s;
        y = (mtx->x1y3 - mtx->x3y1) / s;
        z = (mtx->x2y1 - mtx->x1y2) / s;
        w = .25f * s;
    } else if (mtx->x1y1 > mtx->x2y2 && mtx->x1y1 > mtx->x3y3) {
        const float s = sqrtf(1.0f + mtx->x1y1 - mtx->x2y2 - mtx->x3y3) * 2.0f;
        x = .25f * s;
        y = (mtx->x2y1 + mtx->x1y2) / s;
        z = (mtx->x1y3 + mtx->x3y1) / s;
        w = (mtx->x3y2 - mtx->x2y3) / s;
    } else if (mtx->x2y2 > mtx->x3y3) {
        const float s = sqrtf(1.0f + mtx->x2y2 - mtx->x1y1 - mtx->x3y3) * 2.0f;
        x = (mtx->x2y1 + mtx->x1y2) / s;
        y = .25f * s;
        z = (mtx->x3y2 + mtx->x2y3) / s;
        w = (mtx->x1y3 - mtx->x3y1) / s;
    } else {
        const float s = sqrtf(1.0f + mtx->x3y3 - mtx->x1y1 - mtx->x2y2) * 2.0f;
        x = (mtx->x1y3 + mtx->x3y1) / s;
        y = (mtx->x3y2 + mtx->x2y3) / s;
        z = .25f * s;
        w = (mtx->x2y1 - mtx->x1y2) / s;
    }
    q->x = -z;
    q->y = -x;
    q->z = -y;
    q->w = w;
    q->normalized = false;
}

void quaternion_to_axis_angle(Quaternion *q, float3 *axis, float *angle) {
    quaternion_op_normalize(q);

    const float cos_a = q->w;
    *angle = acosf(cos_a) * 2.0f;

    float sin_a = sqrtf(1.0f - cos_a * cos_a);
    if (fabsf(sin_a) < EPSILON_ZERO_TRANSFORM_RAD) {
        sin_a = 1.0f;
    }

    axis->x = q->y / sin_a;
    axis->y = q->z / sin_a;
    axis->z = q->x / sin_a;
}

void axis_angle_to_quaternion(float3 *axis, const float angle, Quaternion *q) {
    float3_normalize(axis);

    const float a2 = angle * .5f;
    const float sin_a = sinf(a2);
    const float cos_a = cosf(a2);

    q->x = axis->z * sin_a;
    q->y = axis->x * sin_a;
    q->z = axis->y * sin_a;
    q->w = cos_a;
    q->normalized = false;
}

void quaternion_to_euler(Quaternion *q, float3 *euler) {
    quaternion_op_normalize(q);

#if ROTATION_ORDER == 0 // XYZ
    const float singularityCheck = q->w * q->y - q->z * q->x;
    if (singularityCheck > .499f) {
        euler->x = PI_2_F;
        euler->y = -2 * atan2f(q->x, q->w);
        euler->z = 0.0f;
    } else if (singularityCheck < -.499f) {
        euler->x = -PI_2_F;
        euler->y = 2 * atan2f(q->x, q->w);
        euler->z = 0.0f;
    } else {
        const float sr_cp = 2 * (q->w * q->x + q->y * q->z);
        const float cr_cp = 1 - 2 * (q->x * q->x + q->y * q->y);
        const float roll = atan2f(sr_cp, cr_cp);

        const float sp = 2 * singularityCheck;
        const float pitch = asinf(sp);

        const float sy_cp = 2 * (q->w * q->z + q->x * q->y);
        const float cy_cp = 1 - 2 * (q->y * q->y + q->z * q->z);
        const float yaw = atan2f(sy_cp, cy_cp);

        euler->x = pitch;
        euler->y = yaw;
        euler->z = roll;
    }
#elif ROTATION_ORDER == 1 // ZYX
    // TODO: not implemented
#endif

    // remap to [0:2PI]
    if (euler->x < 0)
        euler->x += (float)(2 * M_PI);
    if (euler->y < 0)
        euler->y += (float)(2 * M_PI);
    if (euler->z < 0)
        euler->z += (float)(2 * M_PI);

    /// YZX from:
    /// https://www.euclideanspace.com/maths/geometry/rotations/conversions/quaternionToEuler/
    /*const float test = q->x * q->y + q->z * q->w;
    if (test > .499f) {
        euler->y = 2.0f * atan2f(q->x, q->w);
        euler->z = PI_2_F;
        euler->x = 0.0f;
    } else if (test < -.499f) {
        euler->y = -2.0f * atan2f(q->x, q->w);
        euler->z = -PI_2_F;
        euler->x = 0.0f;
    } else {
        const float sqx = q->x * q->x;
        const float sqy = q->y * q->y;
        const float sqz = q->z * q->z;
        euler->y = atan2f(2.0f * q->y * q->w - 2.0f * q->x * q->z, 1.0f - 2.0f * sqy - 2.0f * sqz);
        euler->z = asinf(2.0f * test);
        euler->x = atan2f(2.0f * q->x * q->w - 2.0f * q->y * q->z, 1.0f - 2.0f * sqx - 2.0f * sqz);
    }*/
}

void euler_to_quaternion(const float x, const float y, const float z, Quaternion *q) {
#if ROTATION_ORDER == 0 // XYZ
    const float cx = cosf(0.5f * x);
    const float sx = sinf(0.5f * x);
    const float cy = cosf(0.5f * y);
    const float sy = sinf(0.5f * y);
    const float cz = cosf(0.5f * z);
    const float sz = sinf(0.5f * z);

    q->x = sz * cx * cy - cz * sx * sy;
    q->y = cz * sx * cy + sz * cx * sy;
    q->z = cz * cx * sy - sz * sx * cy;
    q->w = cz * cx * cy + sz * sx * sy;
#elif ROTATION_ORDER == 1 // ZYX
    const float cx = cosf(0.5f * x);
    const float sx = sinf(0.5f * x);
    const float cy = cosf(0.5f * y);
    const float sy = sinf(0.5f * y);
    const float cz = cosf(0.5f * z);
    const float sz = sinf(0.5f * z);

    q->x = sz * cx * cy + cz * sx * sy;
    q->y = cz * sx * cy - sz * cx * sy;
    q->z = cz * cx * sy + sz * sx * cy;
    q->w = cz * cx * cy - sz * sx * sy;
#endif
    q->normalized = false;

    /// YZX from:
    /// https://www.euclideanspace.com/maths/geometry/rotations/conversions/eulerToQuaternion/
    /*const float cy = cosf(0.5f * y);
    const float sy = sinf(0.5f * y);
    const float cz = cosf(0.5f * z);
    const float sz = sinf(0.5f * z);
    const float cx = cosf(0.5f * x);
    const float sx = sinf(0.5f * x);
    const float cycz = cy * cz;
    const float sysz = sy * sz;
    q->x = cycz * sx + sysz * cx;
    q->y = sy * cz * cx + cy * sz * sx;
    q->z = cy * sz * cx - sy * cz * sx;
    q->w = cycz * cx - sysz * sx;
    q->normalized = false;*/

    /// For testing: using axis angle quaternions
    /// Ref:
    /// https://www.euclideanspace.com/maths/geometry/rotations/conversions/eulerToQuaternion/Euler%20to%20quat.pdf
    /*Quaternion q1, q2, q3;
#if ROTATION_ORDER == 0 // XYZ
    axis_angle_to_quaternion(&float3_right, x, &q1);
    axis_angle_to_quaternion(&float3_up, y, &q2);
    axis_angle_to_quaternion(&float3_forward, z, &q3);
#elif ROTATION_ORDER == 1 // ZYX
    axis_angle_to_quaternion(&float3_right, z, &q1);
    axis_angle_to_quaternion(&float3_up, y, &q2);
    axis_angle_to_quaternion(&float3_forward, x, &q3);
#endif
    Quaternion q12 = quaternion_op_mult(&q2, &q1);
    Quaternion q123 = quaternion_op_mult(&q3, &q12);
    quaternion_set(q, &q123);*/
}

void euler_to_quaternion_vec(const float3 *euler, Quaternion *q) {
    euler_to_quaternion(euler->x, euler->y, euler->z, q);
}

float4 *quaternion_to_float4(Quaternion *q) {
    return float4_new(q->x, q->y, q->z, q->w);
}

Quaternion *float4_to_quaternion(float4 *f) {
    return quaternion_new(f->x, f->y, f->z, f->w, false);
}

// MARK: - Utils -

float quaternion_angle_between(Quaternion *q1, Quaternion *q2) {
    quaternion_op_normalize(q1);
    quaternion_op_normalize(q2);
    return 2.0f * acosf(CLAMP(quaternion_op_dot(q1, q2), -1.0f, 1.0f));
    // The following is equivalent but more expensive:
    /*Quaternion q = quaternion_op_mult(quaternion_op_conjugate(q1), q2);
    return quaternion_angle(&q);*/
}

void quaternion_rotate_vector(Quaternion *q, float3 *v) {
    quaternion_op_normalize(q);

    Quaternion pure = {v->z, v->x, v->y, 0.0f};
    Quaternion q2;
    quaternion_set(&q2, q);
    quaternion_op_inverse(&q2);

    q2 = quaternion_op_mult(&pure, &q2);
    q2 = quaternion_op_mult(q, &q2);

    v->x = q2.y;
    v->y = q2.z;
    v->z = q2.x;
}

void quaternion_op_mult_euler(float3 *euler1, const float3 *euler2) {
    Quaternion q1;
    euler_to_quaternion_vec(euler1, &q1);
    Quaternion q2;
    euler_to_quaternion_vec(euler2, &q2);
    quaternion_op_mult_right(&q2, &q1);
    quaternion_to_euler(&q1, euler1);
}

Quaternion *quaternion_from_to_vectors(const float3 *from, const float3 *to) {
    float3 nfrom = *from, nto = *to;
    float3_normalize(&nfrom);
    float3_normalize(&nto);

    const float d = float3_dot_product(from, to);
    Quaternion *q = quaternion_new_identity();

    // from/to represent the same rotation, return identity
    if (float_isEqual(d, 1.0f, EPSILON_ZERO)) {
        return q;
    }
    // from/to are 180° apart, shortest path is undefined, return rotation around arbitrary axis
    else if (float_isEqual(d, -1.0f, EPSILON_ZERO)) {
        float3 axis = float3_cross_product3(from, &float3_right);
        if (float_isZero(float3_sqr_length(&axis), EPSILON_ZERO)) {
            axis = float3_cross_product3(from, &float3_up);
        }
        float3_normalize(&axis);
        axis_angle_to_quaternion(&axis, PI_F, q);
        return q;
    } else {
        float3 axis = float3_cross_product3(from, to);
        float3_normalize(&axis);
        axis_angle_to_quaternion(&axis, acosf(d), q);
        return q;
    }
}
