#ifndef __DRAWMODES_UNIFORM_SH__
#define __DRAWMODES_UNIFORM_SH__

#if VOXEL_VARIANT_DRAWMODES
uniform vec4 u_overrideParams[2];
#endif

#if DEBUG_FACE == 2
uniform vec4 u_debug_drawSlices[4];
#endif

#if VOXEL_VARIANT_DRAWMODES
#define u_alphaOverride u_overrideParams[0].x
#define u_multRGB vec3(u_overrideParams[0].y, u_overrideParams[0].z, u_overrideParams[0].w)
#define u_addRGB vec3(u_overrideParams[1].x, u_overrideParams[1].y, u_overrideParams[1].z)
#else

#endif

#endif // __DRAWMODES_UNIFORM_SH__
