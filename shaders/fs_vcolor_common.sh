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

#if VCOLOR_VARIANT_UNLIT
	float flag = LIGHTING_UNLIT_FLAG;
#elif VCOLOR_VARIANT_MRT_LIGHTING_PRELIT
	float flag = LIGHTING_PRELIT_FLAG;
#else
	float flag = LIGHTING_LIT_FLAG;
#endif

#if VCOLOR_VARIANT_UNLIT
	vec3 normal = vec3_splat(0.0);
#else
	vec3 normal = encodeNormalUint(v_normal);
#endif

#if VCOLOR_VARIANT_MRT_LIGHTING && VCOLOR_VARIANT_UNLIT == 0
	float linearDepth = v_linearDepth;
#else
	float linearDepth = 0.0;
#endif

	gl_FragData[0] = v_color0;
	gl_FragData[1] = vec4(normal, flag);
	gl_FragData[2] = VOXEL_LIGHT_DEFAULT_RGBS;
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, flag);
#if VCOLOR_VARIANT_MRT_PBR && VCOLOR_VARIANT_MRT_LINEAR_DEPTH
    gl_FragData[4] = vec4_splat(0.0);
    gl_FragData[5] = vec4_splat(linearDepth);
#elif VCOLOR_VARIANT_MRT_PBR
    gl_FragData[4] = vec4_splat(0.0);
#elif VCOLOR_VARIANT_MRT_LINEAR_DEPTH
    gl_FragData[4] = vec4_splat(linearDepth);
#endif // VCOLOR_VARIANT_MRT_PBR + VCOLOR_VARIANT_MRT_LINEAR_DEPTH

#else
	gl_FragColor = v_color0;
#endif // VCOLOR_VARIANT_MRT_LIGHTING
}
