#if FONT_VARIANT_LIGHTING_UNIFORM || FONT_VARIANT_MRT_LINEAR_DEPTH
$input v_color0, v_texcoord0, v_texcoord1
	#define v_linearDepth v_texcoord1.x
	#define v_clipZ v_texcoord1.y
#else
$input v_color0, v_texcoord0
#endif
	#define coloredGlyph CLAMP01(v_texcoord0.w)

#include "./include/bgfx.sh"
#include "./include/config.sh"
#if FONT_VARIANT_LIGHTING_UNIFORM
#include "./include/utils_lib.sh"
#include "./include/game_uniforms.sh"
#include "./include/voxels_uniforms.sh"
#include "./include/global_lighting_uniforms.sh"
#include "./include/voxels_lib.sh"
#endif

#if FONT_VARIANT_LIGHTING_UNIFORM
uniform vec4 u_lighting;
	#define lightValue u_lighting.x
	#define emissive u_lighting.yzw
	#define ambient u_sunColor.xyz
#endif
#if FONT_VARIANT_MRT_LIGHTING
uniform vec4 u_normal;
#endif

SAMPLERCUBE(s_texColor, 0);

void main() {
	vec4 base = textureCube(s_texColor, v_texcoord0.xyz).bgra;
	base.a = mix(base.a, base.r, coloredGlyph);

#if FONT_VARIANT_CUTOUT
	if (base.a <= EPSILON) discard;
#endif

	vec4 color = vec4(mix(base.rgb, v_color0.rgb, coloredGlyph), v_color0.a * base.a);

#if FONT_VARIANT_LIGHTING_UNIFORM && FONT_VARIANT_MRT_LIGHTING == 0 && FONT_VARIANT_UNLIT == 0
	color = getNonVolumeVertexLitColor(color, lightValue, emissive, ambient, v_clipZ);
#endif

#if FONT_VARIANT_MRT_LIGHTING
	gl_FragData[0] = color;
#if FONT_VARIANT_UNLIT
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, LIGHTING_UNLIT_FLAG);
	gl_FragData[2] = VOXEL_LIGHT_DEFAULT_RGBS;
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, LIGHTING_UNLIT_FLAG);
#else
	gl_FragData[1] = vec4(encodeNormalUint(u_normal.xyz), LIGHTING_LIT_FLAG);
#if FONT_VARIANT_LIGHTING_UNIFORM
	gl_FragData[2] = vec4(u_lighting.yzw * VOXEL_LIGHT_RGB_PRE_FACTOR, u_lighting.x);
	gl_FragData[3] = vec4(u_lighting.yzw * VOXEL_LIGHT_RGB_POST_FACTOR, LIGHTING_LIT_FLAG);
#else
	gl_FragData[2] = VOXEL_LIGHT_DEFAULT_RGBS;
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, LIGHTING_LIT_FLAG);
#endif // FONT_VARIANT_LIGHTING_UNIFORM
#endif // FONT_VARIANT_UNLIT
#if FONT_VARIANT_MRT_LINEAR_DEPTH
	gl_FragData[4] = vec4_splat(v_linearDepth);
#endif // FONT_VARIANT_MRT_LINEAR_DEPTH
#else
	gl_FragColor = color;
#endif // FONT_VARIANT_MRT_LIGHTING
}
