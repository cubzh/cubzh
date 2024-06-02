$input v_color0, v_texcoord0
#define v_dir v_color0

#include "./include/bgfx.sh"
#include "./include/config.sh"
#include "./include/game_uniforms.sh"
#include "./include/global_lighting_uniforms.sh"
#include "./include/dithering_lib.sh"

#define uv v_texcoord0.xy
#define pos v_texcoord0.zw

#if SKYBOX_VARIANT_CUBEMAPS
SAMPLERCUBE(s_cubeDay, 0);
SAMPLERCUBE(s_cubeNight, 1);
#endif

void main() {
	vec3 dir = normalize(v_dir).xyz;

	vec4 bg = mix(mix(u_horizonColor, u_abyssColor, abs(dir.y)),
		mix(u_horizonColor, u_skyColor, dir.y),
		step(0.0, dir.y));

#if SKYBOX_VARIANT_CUBEMAPS
	vec4 day = textureCube(s_cubeDay, dir);
	vec4 night = textureCube(s_cubeNight, dir);

	vec4 fg = mix(day, night, u_dayNight);
	vec3 blend = BLEND_SOFT_ADDITIVE(fg, bg).xyz;
#else
	vec3 blend = bg.xyz;
#endif

#if SKYBOX_COLOURING_ENABLED
	blend = u_sunColor.xyz * blend;
#endif

#if SKYBOX_DITHERING
	blend = dither(pos, uv, blend);
#endif

#if SKYBOX_VARIANT_MRT_CLEAR
	gl_FragData[0] = vec4(blend, 1.0);
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, LIGHTING_UNLIT_FLAG);
	gl_FragData[2] = vec4_splat(0.0);
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, LIGHTING_UNLIT_FLAG);
#if SKYBOX_VARIANT_MRT_CLEAR_LINEAR_DEPTH
	gl_FragData[4] = vec4_splat(0.0);
#endif // SKYBOX_VARIANT_MRT_CLEAR_LINEAR_DEPTH
#else
	gl_FragColor = vec4(blend, 1.0);
#endif // SKYBOX_VARIANT_MRT_CLEAR
}
