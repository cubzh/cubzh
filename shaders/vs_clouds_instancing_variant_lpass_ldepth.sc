/*
 * Instanced clouds vertex shader variant: lighting pass, linear depth
 */

// No compute, instances are static
#define SKY_VARIANT_COMPUTE 0

// Multiple render target lighting and linear depth
#define SKY_VARIANT_MRT_LIGHTING 1
#define SKY_VARIANT_MRT_LINEAR_DEPTH 1

#include "./vs_clouds_instancing_common.sh"
