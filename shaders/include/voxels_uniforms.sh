#ifndef __VOXELS_UNIFORM_SH__
#define __VOXELS_UNIFORM_SH__

#if VOXEL_VARIANT_LIGHTING_UNIFORM
uniform vec4 u_lighting;
#endif
#if VOXEL_VARIANT_DRAWMODE_OVERRIDES || VOXEL_VARIANT_DRAWMODE_OUTLINE
uniform vec4 u_overrideParams[2];
#endif
#if DEBUG_FACE == 2
uniform vec4 u_debug_drawSlices[4];
#endif

#if VOXEL_VARIANT_DRAWMODE_OVERRIDES
#define u_alphaOverride u_overrideParams[0].x
#define u_multRGB vec3(u_overrideParams[0].y, u_overrideParams[0].z, u_overrideParams[0].w)
#define u_addRGB vec3(u_overrideParams[1].x, u_overrideParams[1].y, u_overrideParams[1].z)
#elif VOXEL_VARIANT_DRAWMODE_OUTLINE
#define u_outlineThickness u_overrideParams[0].x
#define u_outlineRGBA vec4(u_overrideParams[0].y, u_overrideParams[0].z, u_overrideParams[0].w, u_overrideParams[1].x)
#define u_projSize vec2(u_overrideParams[1].y, u_overrideParams[1].z)
#endif

#endif // __VOXELS_UNIFORM_SH__
