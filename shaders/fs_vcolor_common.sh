#if VCOLOR_VARIANT_MRT_LIGHTING && VCOLOR_VARIANT_UNLIT == 0
$input v_color0, v_texcoord0
	#define v_normal v_texcoord0.xyz
	#define v_linearDepth v_texcoord0.w
#else
$input v_color0
#endif

#include "./include/bgfx.sh"
#include "./include/config.sh"
#if VCOLOR_VARIANT_MRT_LIGHTING
#include "./include/utils_lib.sh"
#endif

void main() {
#if VCOLOR_VARIANT_MRT_LIGHTING
	gl_FragData[0] = v_color0;
#if VCOLOR_VARIANT_UNLIT
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, LIGHTING_UNLIT_FLAG);
	gl_FragData[2] = VOXEL_LIGHT_DEFAULT_RGBS;
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, LIGHTING_UNLIT_FLAG);
#if VCOLOR_VARIANT_MRT_LINEAR_DEPTH
	gl_FragData[4] = vec4_splat(0.0);
#endif // VCOLOR_VARIANT_MRT_LINEAR_DEPTH
#elif VCOLOR_VARIANT_MRT_LIGHTING_PRELIT
	gl_FragData[1] = vec4(encodeNormalUint(v_normal), LIGHTING_PRELIT_FLAG);
	gl_FragData[2] = VOXEL_LIGHT_DEFAULT_RGBS;
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, LIGHTING_PRELIT_FLAG);
#if VCOLOR_VARIANT_MRT_LINEAR_DEPTH
	gl_FragData[4] = vec4_splat(v_linearDepth);
#endif // VCOLOR_VARIANT_MRT_LINEAR_DEPTH
#else
	gl_FragData[1] = vec4(encodeNormalUint(v_normal), LIGHTING_LIT_FLAG);
	gl_FragData[2] = VOXEL_LIGHT_DEFAULT_RGBS;
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, LIGHTING_LIT_FLAG);
#if VCOLOR_VARIANT_MRT_LINEAR_DEPTH
	gl_FragData[4] = vec4_splat(v_linearDepth);
#endif // VCOLOR_VARIANT_MRT_LINEAR_DEPTH
#endif // VCOLOR_VARIANT_UNLIT
#else
	gl_FragColor = v_color0;
#endif // VCOLOR_VARIANT_MRT_LIGHTING
}
