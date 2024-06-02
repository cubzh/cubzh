#if QUAD_VARIANT_TEX

#if QUAD_VARIANT_MRT_LIGHTING && QUAD_VARIANT_MRT_LINEAR_DEPTH
$input v_color0, v_color1, v_texcoord0, v_texcoord1
	#define v_lighting v_color1
	#define v_linearDepth v_texcoord1.x
#elif QUAD_VARIANT_MRT_LIGHTING
$input v_color0, v_color1, v_texcoord0
	#define v_lighting v_color1
#else
$input v_color0, v_texcoord0
#endif
	#define v_uv v_texcoord0.xy

#else // QUAD_VARIANT_TEX

#if QUAD_VARIANT_MRT_LIGHTING && QUAD_VARIANT_MRT_LINEAR_DEPTH
$input v_color0, v_color1, v_texcoord0
	#define v_lighting v_color1
	#define v_linearDepth v_texcoord0.x
#elif QUAD_VARIANT_MRT_LIGHTING
$input v_color0, v_color1
	#define v_lighting v_color1
#else
$input v_color0
#endif

#endif // QUAD_VARIANT_TEX

#include "./include/bgfx.sh"
#include "./include/config.sh"
#if QUAD_VARIANT_MRT_LIGHTING
#include "./include/utils_lib.sh"
#endif

#if QUAD_VARIANT_MRT_LIGHTING
uniform vec4 u_color1;
#define u_normal u_color1
#endif

#if QUAD_VARIANT_TEX
SAMPLER2D(s_fb1, 0);

uniform vec4 u_params;
	#define u_tiling u_params.xy
	#define u_offset u_params.zw
#endif

void main() {
	vec4 color = v_color0;

#if QUAD_VARIANT_TEX
	color *= texture2D(s_fb1, u_tiling * v_uv + u_offset);
#endif

#if QUAD_VARIANT_MRT_LIGHTING
	gl_FragData[0] = color;
#if QUAD_VARIANT_UNLIT
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, LIGHTING_UNLIT_FLAG);
	gl_FragData[2] = VOXEL_LIGHT_DEFAULT_RGBS;
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, LIGHTING_UNLIT_FLAG);
#else
	gl_FragData[1] = vec4(encodeNormalUint(u_normal.xyz), LIGHTING_LIT_FLAG);
	gl_FragData[2] = vec4(v_lighting.yzw * VOXEL_LIGHT_RGB_PRE_FACTOR, v_lighting.x);
	gl_FragData[3] = vec4(v_lighting.yzw * VOXEL_LIGHT_RGB_POST_FACTOR, LIGHTING_LIT_FLAG);
#endif // QUAD_VARIANT_UNLIT
#if QUAD_VARIANT_MRT_LINEAR_DEPTH
	gl_FragData[4] = vec4_splat(v_linearDepth);
#endif
#else
	gl_FragColor = color;
#endif // QUAD_VARIANT_MRT_LIGHTING
}
