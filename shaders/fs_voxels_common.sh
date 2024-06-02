#if VOXEL_VARIANT_MRT_LIGHTING
$input v_color0, v_color1, v_texcoord0, v_texcoord1
	#define v_lighting v_color1
	#define v_normal v_texcoord0.xyz
	#define v_clipZ v_texcoord0.w
	#define v_model v_texcoord1.xyz
	#define v_linearDepth v_texcoord1.w
#elif VOXEL_VARIANT_MRT_TRANSPARENCY || VOXEL_VARIANT_DRAWMODES
$input v_color0, v_texcoord0
	#define v_model v_texcoord0.xyz
	#define v_clipZ v_texcoord0.w
#else
$input v_color0
#endif

#include "./include/bgfx.sh"
#include "./include/config.sh"
#if VOXEL_VARIANT_DRAWMODES
#include "./include/drawmodes_lib.sh"
#include "./include/voxels_uniforms_fs.sh"
#elif VOXEL_VARIANT_MRT_LIGHTING
#include "./include/utils_lib.sh"
#endif

void main() {
#if VOXEL_VARIANT_DRAWMODES
	vec4 color = getGridColor(v_model, v_color0, u_gridRGB, u_gridScaleMag, v_clipZ);
#else
	vec4 color = v_color0;
#endif
#if VOXEL_VARIANT_MRT_LIGHTING
	gl_FragData[0] = color;
#if VOXEL_VARIANT_UNLIT
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, LIGHTING_UNLIT_FLAG);
	gl_FragData[2] = VOXEL_LIGHT_DEFAULT_RGBS;
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, LIGHTING_UNLIT_FLAG);
#else
	gl_FragData[1] = vec4(encodeNormalUint(v_normal), LIGHTING_LIT_FLAG);
	gl_FragData[2] = vec4(v_lighting.yzw * VOXEL_LIGHT_RGB_PRE_FACTOR, v_lighting.x);
	gl_FragData[3] = vec4(v_lighting.yzw * VOXEL_LIGHT_RGB_POST_FACTOR, LIGHTING_LIT_FLAG);
#endif // VOXEL_VARIANT_UNLIT
#if VOXEL_VARIANT_MRT_LINEAR_DEPTH
	gl_FragData[4] = vec4_splat(v_linearDepth);
#endif // VOXEL_VARIANT_MRT_LINEAR_DEPTH
#else
	gl_FragColor = color;
#endif // VOXEL_VARIANT_MRT_LIGHTING
}
