#define IS_SHADOW_PASS (VOXEL_VARIANT_MRT_SHADOW_PACK || VOXEL_VARIANT_MRT_SHADOW_SAMPLE)

$input a_position, a_texcoord0
#if VOXEL_VARIANT_MRT_LIGHTING
$output v_color0, v_color1, v_texcoord0, v_texcoord1
	#define v_lighting v_color1
	#define v_normal v_texcoord0.xyz
	#define v_clipZ v_texcoord0.w
	#define v_model v_texcoord1.xyz
	#define v_linearDepth v_texcoord1.w
#elif VOXEL_VARIANT_MRT_TRANSPARENCY || VOXEL_VARIANT_DRAWMODES
$output v_color0, v_texcoord0, v_texcoord1
	#define v_model v_texcoord0.xyz
	#define v_clipZ v_texcoord0.w
#elif VOXEL_VARIANT_MRT_SHADOW_SAMPLE == 0
$output v_color0
	#define v_depth v_color0.x
#endif

#include "./include/bgfx.sh"
#include "./include/config.sh"
#include "./include/game_uniforms.sh"
#include "./include/global_lighting_uniforms.sh"
#include "./include/voxels_lib.sh"
#if VOXEL_VARIANT_DRAWMODES
#include "./include/drawmodes_uniforms.sh"
#endif

#if IS_SHADOW_PASS == false
SAMPLER2D(s_palette, 0);
#endif

uniform vec4 u_params;
	#define u_metadata u_params.x

#define a_colorIdx a_position.w
#define a_metadata a_texcoord0.x

void main() {
	vec3 attmeta = unpackAttributesMetadata(a_metadata);
	vec3 unimeta = unpackUniformMetadata(u_metadata);

	int aoIdx = int(attmeta.x);
	int face = int(attmeta.y);
	float unlit = unimeta.x;
	float baked = unimeta.y;
	vec4 sample = unpackVoxelLight(unimeta.z);

	vec4 model = vec4(a_position.xyz, 1.0);
	vec4 clip = mul(u_modelViewProj, model);
	//float depth = fromClipSpaceDepth(clip.z / clip.w);

#if IS_SHADOW_PASS

	gl_Position = clip;
#if VOXEL_VARIANT_MRT_SHADOW_PACK
	v_depth = clip.z / clip.w;
#endif

#else // IS_SHADOW_PASS

#if VOXEL_VARIANT_MRT_LIGHTING
	vec3 wnormal = normalize(mul(u_model[0], vec4(getVertexNormal(face), 0.0)).xyz);
#if VOXEL_VARIANT_MRT_LINEAR_DEPTH
	vec4 view = mul(u_modelView, model);
#endif // VOXEL_VARIANT_MRT_LINEAR_DEPTH
#endif // VOXEL_VARIANT_MRT_LIGHTING

#if ENABLE_AO
	float aoValue = AO_GRADIENT[aoIdx];
#else
	float aoValue = 0.0;
#endif // ENABLE_AO

	vec4 voxelLight = mix(mix(sample, BLEND_SOFT_ADDITIVE(unpackVoxelLight(attmeta.z), sample), baked), VOXEL_LIGHT_DEFAULT_SRGB, unlit);
	voxelLight.x = saturate(voxelLight.x * u_bakedIntensity);

	vec2 paletteUV = getPaletteUV(a_colorIdx);
	vec4 color = texture2DLod(s_palette, paletteUV, 0.0);
#if DEBUG_FACE > 0
	color = getDebugColor(color, face, clip.xyz / clip.w);
#endif
#if AO_COLOR == 4
	vec4 comp = texture2DLod(s_palette, vec2(paletteUV.x, paletteUV.y + 1.0 / u_paletteSize), 0.0);
#else
	vec4 comp = CLEAR;
#endif

#if VOXEL_VARIANT_DRAWMODES
	float aStep = step(1.0, u_alphaOverride);
	color.w = mix(u_alphaOverride, color.w, aStep);
	aoValue = mix(0.0, aoValue, aStep);

	color.xyz *= u_multRGB;
	color.xyz += u_addRGB;
#endif

	vec3 skybox = mix(u_sunColor.xyz, vec3_splat(1.0), unlit);

#if DEBUG_VERTEX_LIGHTING > 0
	vec4 vcolor = getVertexDebugColor(voxelLight, skybox, aoValue, color, comp.xyz, face);
#elif VOXEL_VARIANT_MRT_LIGHTING
	vec4 vcolor = getVertexDeferredAlbedo(aoValue, color, comp.xyz, face);
	voxelLight = getVertexDeferredLighting(voxelLight, aoValue);
#else
	vec4 vcolor = getVertexLitColor(voxelLight, skybox, aoValue, color, comp.xyz, clip.z, face);
#endif

	gl_Position = clip;
	v_color0 = vcolor;
#if VOXEL_VARIANT_DRAWMODES || VOXEL_VARIANT_MRT_TRANSPARENCY
	v_model = model.xyz;
	v_clipZ = clip.z;
#endif
#if VOXEL_VARIANT_MRT_LIGHTING
	v_normal = wnormal;
	v_lighting = voxelLight;
#if VOXEL_VARIANT_MRT_LINEAR_DEPTH
	v_linearDepth = view.z;
#endif // VOXEL_VARIANT_MRT_LINEAR_DEPTH
#endif

#endif // IS_SHADOW_PASS
}
