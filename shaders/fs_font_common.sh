$input v_color0, v_texcoord0, v_texcoord1
	#define v_linearDepth v_texcoord1.x
	#define v_clipZ v_texcoord1.y

#include "./include/bgfx.sh"
#include "./include/config.sh"
#include "./include/font_lib.sh"
#include "./include/utils_lib.sh"
#if FONT_VARIANT_UNLIT == 0
#include "./include/game_uniforms.sh"
#include "./include/global_lighting_uniforms.sh"
#include "./include/voxels_lib.sh"
#endif

uniform vec4 u_params;
	#define u_metadata u_params.x
	#define u_vlighting u_params.y
	#define u_outlineColor u_params.z
#if FONT_VARIANT_MRT_LIGHTING
uniform vec4 u_normal;
#endif

SAMPLERCUBE(s_atlas, 0);
SAMPLERCUBE(s_atlasPoint, 1);

void main() {
	vec3 metadata1 = unpackFontUniformMetadata(u_metadata);
	#define weight metadata1.x
	#define softness metadata1.y
	#define outlineWeight metadata1.z
#if FONT_VARIANT_UNLIT == 0
	vec4 vlighting = unpackVoxelLight(u_vlighting);
#endif
	vec2 metadata2 = unpackFontAttributesMetadata(v_texcoord0.w);
	#define colored metadata2.x
	#define filtering metadata2.y

	vec4 base = mix(textureCube(s_atlasPoint, v_texcoord0.xyz).bgra,
					textureCube(s_atlas, v_texcoord0.xyz).bgra,
					filtering);
	base.a = mix(base.r, base.a, colored);

	if (base.a <= EPSILON) discard;

	float totalWeight = 1.0 - clamp(weight + outlineWeight, 0, 1.0 - 2.5 * softness);
	float alpha = smoothstep(totalWeight - softness, totalWeight + softness, base.r);
	float outline = smoothstep(1.0 - weight - 2.0 * softness, 1.0 - weight, base.r);
	vec3 rgb = mix(unpackFloatToRgb(u_outlineColor), v_color0.rgb, outline);
	base = mix(vec4(rgb, alpha), base, colored);

	vec4 color = vec4(base.rgb, v_color0.a * base.a);

#if FONT_VARIANT_MRT_LIGHTING == 0 && FONT_VARIANT_UNLIT == 0
	color = getNonVoxelVertexLitColor(color, vlighting.x, vlighting.yzw, u_sunColor.xyz, v_clipZ);
#endif

#if FONT_VARIANT_MRT_LIGHTING
	gl_FragData[0] = color;
#if FONT_VARIANT_UNLIT
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, LIGHTING_UNLIT_FLAG);
	gl_FragData[2] = VOXEL_LIGHT_DEFAULT_RGBS;
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, LIGHTING_UNLIT_FLAG);
#else
	gl_FragData[1] = vec4(normToUnorm3(u_normal.xyz), LIGHTING_LIT_FLAG);
	gl_FragData[2] = vec4(vlighting.yzw * VOXEL_LIGHT_RGB_PRE_FACTOR, vlighting.x);
	gl_FragData[3] = vec4(vlighting.yzw * VOXEL_LIGHT_RGB_POST_FACTOR, LIGHTING_LIT_FLAG);
#endif // FONT_VARIANT_UNLIT
#if FONT_VARIANT_MRT_PBR && FONT_VARIANT_MRT_LINEAR_DEPTH
    gl_FragData[4] = vec4_splat(0.0);
    gl_FragData[5] = vec4_splat(v_linearDepth);
#elif FONT_VARIANT_MRT_PBR
    gl_FragData[4] = vec4_splat(0.0);
#elif FONT_VARIANT_MRT_LINEAR_DEPTH
    gl_FragData[4] = vec4_splat(v_linearDepth);
#endif // FONT_VARIANT_MRT_PBR + FONT_VARIANT_MRT_LINEAR_DEPTH
#else
	gl_FragColor = color;
#endif // FONT_VARIANT_MRT_LIGHTING
}
