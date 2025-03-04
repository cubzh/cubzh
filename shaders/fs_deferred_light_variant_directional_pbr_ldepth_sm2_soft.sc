/*
 * Deferred light shader variant: directional, linear depth g-buffer, shadows, PBR
 */

// Directional light
#define LIGHT_VARIANT_TYPE_POINT 0
#define LIGHT_VARIANT_TYPE_SPOT 0
#define LIGHT_VARIANT_TYPE_DIRECTIONAL 1

// Linear depth in g-buffer
#define LIGHT_VARIANT_LINEAR_DEPTH 1

// Shadows w/ depth packing, 2 cascades, soft
#define LIGHT_VARIANT_SHADOW_PACK 1
#define LIGHT_VARIANT_SHADOW_SAMPLE 0
#define LIGHT_VARIANT_SHADOW_CSM 2
#define LIGHT_VARIANT_SHADOW_SOFT 1

// PBR model
#define LIGHT_VARIANT_PBR 1

#include "./fs_deferred_light_common.sh"