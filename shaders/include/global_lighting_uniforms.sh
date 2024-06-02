#ifndef __LIGHTING_UNIFORM_SH__
#define __LIGHTING_UNIFORM_SH__

uniform vec4 u_fogColor;
uniform vec4 u_sunColor;
uniform vec4 u_skyColor;
uniform vec4 u_horizonColor;
uniform vec4 u_abyssColor;

#define u_dayNight 0.0 // currently unused

#define u_faceShading u_fogColor.w
#define u_fogStart u_sunColor.w
#define u_fogLength u_skyColor.w
#define u_skyAmbientFactor u_horizonColor.w
#define u_emissiveFog u_abyssColor.w

#define u_fogEnd u_fogStart + u_fogLength

#endif // __LIGHTING_UNIFORM_SH__
