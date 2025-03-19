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
#include "./include/quad_lib.sh"
#if QUAD_VARIANT_MRT_LIGHTING
#include "./include/game_uniforms.sh"
#include "./include/global_lighting_uniforms.sh"
#include "./include/voxels_lib.sh"
#endif

#if QUAD_VARIANT_TEX
SAMPLER2D(s_fb1, 0);

uniform vec4 u_params;
	#define u_slice u_params.xy
	#define u_uBorders u_params.zw
#endif
#if QUAD_VARIANT_TEX || QUAD_VARIANT_CUTOUT
uniform vec4 u_color1;
	#define u_vBorders u_color1.xy
	#define u_cutout u_color1.z
#endif

void main() {
	vec4 color = v_color0;

#if QUAD_VARIANT_MRT_LIGHTING || QUAD_VARIANT_TEX
	//vec3 wnormal = normalize(-u_model[0][2].xyz);

	float meta[7]; unpackQuadFullMetadata(v_metadata, meta);
	float unlit = mix(LIGHTING_LIT_FLAG, LIGHTING_UNLIT_FLAG, meta[0]);
	float unpack9SliceNormal = meta[1];
	float cutout = meta[2];
	vec4 srgb = vec4(meta[3], meta[4], meta[5], meta[6]);
#endif

#if QUAD_VARIANT_TEX
	vec2 slice = mix(u_slice, unpackNormalized2Floats(v_normal.x), unpack9SliceNormal);
	vec2 uBorders = mix(u_uBorders, unpackNormalized2Floats(v_normal.y), unpack9SliceNormal);
	vec2 vBorders = mix(u_vBorders, unpackNormalized2Floats(v_normal.z), unpack9SliceNormal);
	
	vec2 uv = vec2(sliceUV(v_uv.x, uBorders, slice.x),
				   sliceUV(v_uv.y, vBorders, slice.y));
	
	color *= texture2D(s_fb1, uv);
#endif

#if QUAD_VARIANT_CUTOUT
	if (color.a <= mix(-1.0, u_cutout, cutout)) discard;
#endif
#if QUAD_VARIANT_ALPHA == 0
	color.a = 1.0;
#endif

#if QUAD_VARIANT_MRT_LIGHTING
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(normToUnorm3(v_normal), unlit);
	gl_FragData[2] = vec4(srgb.yzw * VOXEL_LIGHT_RGB_PRE_FACTOR, srgb.x * u_bakedIntensity);
	gl_FragData[3] = vec4(srgb.yzw * VOXEL_LIGHT_RGB_POST_FACTOR, unlit);
#if QUAD_VARIANT_MRT_PBR && QUAD_VARIANT_MRT_LINEAR_DEPTH
    gl_FragData[4] = vec4_splat(0.0);
    gl_FragData[5] = vec4_splat(v_linearDepth);
#elif QUAD_VARIANT_MRT_PBR
    gl_FragData[4] = vec4_splat(0.0);
#elif QUAD_VARIANT_MRT_LINEAR_DEPTH
    gl_FragData[4] = vec4_splat(v_linearDepth);
#endif // QUAD_VARIANT_MRT_PBR + QUAD_VARIANT_MRT_LINEAR_DEPTH
#else
	gl_FragColor = color;
#endif // QUAD_VARIANT_MRT_LIGHTING
}
