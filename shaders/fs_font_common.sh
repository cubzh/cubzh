#if FONT_VARIANT_LIGHTING_UNIFORM || FONT_VARIANT_MRT_LINEAR_DEPTH
$input v_color0, v_texcoord0, v_texcoord1
	#define v_linearDepth v_texcoord1.x
	#define v_clipZ v_texcoord1.y
#else
$input v_color0, v_texcoord0
#endif

#include "./include/bgfx.sh"
#include "./include/config.sh"
#include "./include/font_lib.sh"
#include "./include/utils_lib.sh"
#if FONT_VARIANT_LIGHTING_UNIFORM
#include "./include/game_uniforms.sh"
#include "./include/voxels_uniforms.sh"
#include "./include/global_lighting_uniforms.sh"
#include "./include/voxels_lib.sh"
#endif

uniform vec4 u_params;
	#define weight u_params.x
	#define softness u_params.y
	#define outlineColor u_params.z
	#define outlineWeight u_params.w
#if FONT_VARIANT_LIGHTING_UNIFORM
uniform vec4 u_lighting;
	#define lightValue u_lighting.x
	#define emissive u_lighting.yzw
	#define ambient u_sunColor.xyz
#endif
#if FONT_VARIANT_MRT_LIGHTING
uniform vec4 u_normal;
#endif

SAMPLERCUBE(s_atlas, 0);
SAMPLERCUBE(s_atlasPoint, 1);

void main() {
	vec2 metadata = unpackFontMetadata(v_texcoord0.w);
	#define colored metadata.x
	#define filtering metadata.y

	vec4 base = mix(textureCube(s_atlasPoint, v_texcoord0.xyz).bgra,
					textureCube(s_atlas, v_texcoord0.xyz).bgra,
					filtering);
	base.a = mix(base.r, base.a, colored);

	if (base.a <= EPSILON) discard;

	float totalWeight = 1.0 - clamp(weight + outlineWeight, 0, 1.0 - 2.5 * softness);
	float alpha = smoothstep(totalWeight - softness, totalWeight + softness, base.r);
	float outline = smoothstep(1.0 - weight - 2.0 * softness, 1.0 - weight, base.r);
	vec3 rgb = mix(unpackFloatToRgb(outlineColor), v_color0.rgb, outline);
	base = mix(vec4(rgb, alpha), base, colored);

	vec4 color = vec4(base.rgb, v_color0.a * base.a);

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
	gl_FragData[2] = vec4(emissive * VOXEL_LIGHT_RGB_PRE_FACTOR, lightValue);
	gl_FragData[3] = vec4(emissive * VOXEL_LIGHT_RGB_POST_FACTOR, LIGHTING_LIT_FLAG);
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
