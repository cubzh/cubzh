#ifndef __COMMON_UNIFORM_SH__
#define __COMMON_UNIFORM_SH__

uniform vec4 u_gameParams[2];

#define u_fov u_gameParams[0].x
#define u_time u_gameParams[0].y
#define u_far u_gameParams[0].z
#define u_paletteSize u_gameParams[0].w
#define u_bakedIntensity u_gameParams[1].x

#define u_mapSize 1.0 // deprecated
#define u_mapInverseScale 1.0 // deprecated

#endif // __COMMON_UNIFORM_SH__
