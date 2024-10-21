#ifndef __VOXELS_FS_UNIFORM_SH__
#define __VOXELS_FS_UNIFORM_SH__

#if VOXEL_VARIANT_DRAWMODE_OVERRIDES
uniform vec4 u_overrideParams_fs;

#define u_gridScaleMag u_overrideParams_fs.x
#define u_gridRGB vec3(u_overrideParams_fs.y, u_overrideParams_fs.z, u_overrideParams_fs.w)
#else

#endif

#endif // __VOXELS_FS_UNIFORM_SH__
