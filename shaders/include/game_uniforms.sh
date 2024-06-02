#ifndef __COMMON_UNIFORM_SH__
#define __COMMON_UNIFORM_SH__

uniform vec4 u_gameParams;

#define u_fov u_gameParams.x
#define u_time u_gameParams.y
#define u_far u_gameParams.z
#define u_paletteSize u_gameParams.w
#define u_mapSize 1.0 // deprecated
#define u_mapInverseScale 1.0 // deprecated

#endif // __COMMON_UNIFORM_SH__
