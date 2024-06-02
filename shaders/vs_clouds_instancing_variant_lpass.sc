/*
 * Instanced clouds vertex shader variant: lighting pass
 */

// No compute, instances are static
#define SKY_VARIANT_COMPUTE 0

// Multiple render target lighting
#define SKY_VARIANT_MRT_LIGHTING 1
#define SKY_VARIANT_MRT_LINEAR_DEPTH 0

#include "./vs_clouds_instancing_common.sh"
