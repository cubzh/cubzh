#if QUAD_VARIANT_MRT_LIGHTING || QUAD_VARIANT_TEX
$input v_color0, v_texcoord0, v_texcoord1
	#define v_uv v_texcoord0.xy
	#define v_metadata v_texcoord0.z
	#define v_linearDepth v_texcoord0.w
	#define v_normal v_texcoord1.xyz
#else
$input v_color0
#endif

#include "./include/bgfx.sh"
#include "./include/config.sh"
#include "./include/utils_lib.sh"
#if QUAD_VARIANT_TEX
#include "./include/quad_lib.sh"
#endif
#if QUAD_VARIANT_MRT_LIGHTING
#include "./include/game_uniforms.sh"
#include "./include/voxels_uniforms.sh"
#include "./include/global_lighting_uniforms.sh"
#include "./include/voxels_lib.sh"
#endif

#if QUAD_VARIANT_TEX
SAMPLER2D(s_fb1, 0);

uniform vec4 u_params;
uniform vec4 u_color1;
	#define u_slice u_params.xy
	#define u_uBorders u_params.zw
	#define u_vBorders u_color1.xy
#endif

void main() {
	vec4 color = v_color0;

#if QUAD_VARIANT_MRT_LIGHTING
	//vec3 wnormal = normalize(-u_model[0][2].xyz);

	float meta[5]; unpackQuadFullMetadata(v_metadata, meta);
	float unlit = mix(LIGHTING_LIT_FLAG, LIGHTING_UNLIT_FLAG, meta[0]);
	vec4 srgb = vec4(meta[1], meta[2], meta[3], meta[4]);
#else
	float unlit = 1.0f;
#endif

#if QUAD_VARIANT_TEX
	vec2 slice = mix(u_slice, unpackNormalized2Floats(v_normal.x), unlit);
	vec2 uBorders = mix(u_uBorders, unpackNormalized2Floats(v_normal.y), unlit);
	vec2 vBorders = mix(u_vBorders, unpackNormalized2Floats(v_normal.z), unlit);
	
	vec2 uv = vec2(sliceUV(v_uv.x, uBorders, slice.x),
				   sliceUV(v_uv.y, vBorders, slice.y));
	
	color *= texture2D(s_fb1, uv);
#endif

#if QUAD_VARIANT_MRT_LIGHTING
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(encodeNormalUint(v_normal), unlit);
	gl_FragData[2] = vec4(srgb.yzw * VOXEL_LIGHT_RGB_PRE_FACTOR, srgb.x * u_bakedIntensity);
	gl_FragData[3] = vec4(srgb.yzw * VOXEL_LIGHT_RGB_POST_FACTOR, unlit);
#if QUAD_VARIANT_MRT_LINEAR_DEPTH
	gl_FragData[4] = vec4_splat(v_linearDepth);
#endif
#else
	gl_FragColor = color;
#endif // QUAD_VARIANT_MRT_LIGHTING
}
