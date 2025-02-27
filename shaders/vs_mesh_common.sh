#define IS_SHADOW_PASS (MESH_VARIANT_MRT_SHADOW_PACK || MESH_VARIANT_MRT_SHADOW_SAMPLE)

$input a_position, a_normal, a_tangent, a_texcoord0, a_color0
#if IS_SHADOW_PASS

#if MESH_VARIANT_MRT_SHADOW_PACK
$output v_color0
	#define v_depth v_color0.x
#endif

#else // IS_SHADOW_PASS

#if MESH_VARIANT_MRT_LIGHTING
$output v_color0, v_texcoord0, v_texcoord1, v_texcoord2
    #define v_uv v_texcoord0.xy
	#define v_linearDepth v_texcoord0.z
	#define v_normal v_texcoord1.xyz
    #define v_tangent v_texcoord2.xyz
    #define v_bitangentX v_texcoord0.w
    #define v_bitangentY v_texcoord1.w
    #define v_bitangentZ v_texcoord2.w
#else
$output v_color0, v_texcoord0
    #define v_uv v_texcoord0.xy
    #define v_cutout v_texcoord0.z
    #define v_albedoFlag v_texcoord0.w
#endif

#if MESH_VARIANT_MRT_LIGHTING == 0
uniform vec4 u_lighting;
uniform vec4 u_params;
    #define u_metadata u_params.x
    #define u_emissive u_params.y
    #define u_cutout u_params.z
    #define u_unlit u_params.w
#endif

#endif // IS_SHADOW_PASS

#include "./include/bgfx.sh"
#if MESH_VARIANT_MRT_LIGHTING == 0
#include "./include/game_uniforms.sh"
#include "./include/global_lighting_uniforms.sh"
#include "./include/voxels_lib.sh"
#include "./include/mesh_lib.sh"
#endif

void main() {
    vec4 model = vec4(a_position.xyz, 1.0);
    vec4 clip = mul(u_modelViewProj, model);

#if IS_SHADOW_PASS

    gl_Position = clip;
#if MESH_VARIANT_MRT_SHADOW_PACK
    v_depth = clip.z / clip.w;
#endif

#else // IS_SHADOW_PASS

#if MESH_VARIANT_MRT_LIGHTING
    vec4 color = a_color0;
#if MESH_VARIANT_MRT_LINEAR_DEPTH
    vec4 view = mul(u_modelView, model);
#endif
    vec3 wnormal = normalize(mul(u_model[0], vec4(a_normal, 0.0)).xyz);
	vec3 wtangent = normalize(mul(u_model[0], vec4(a_tangent, 0.0)).xyz);
    vec3 wbitangent = cross(wnormal, wtangent);// * a_tangent.w;
#else
    vec4 color = mix(getNonVoxelVertexLitColor(a_color0, u_lighting.x, u_lighting.yzw, u_sunColor.xyz, clip.z), a_color0, u_unlit);
#endif // MESH_VARIANT_MRT_LIGHTING

    gl_Position = clip;
    v_color0 = color;
    v_uv = a_texcoord0.xy;
#if MESH_VARIANT_MRT_LIGHTING
#if MESH_VARIANT_MRT_LINEAR_DEPTH
    v_linearDepth = view.z;
#endif
    v_normal = wnormal;
    v_tangent = wtangent;
    v_bitangentX = wbitangent.x;
    v_bitangentY = wbitangent.y;
    v_bitangentZ = wbitangent.z;
#else
    v_cutout = u_cutout;
    v_albedoFlag = unpackMeshMetadata_albedoFlag(u_metadata);
#endif // MESH_VARIANT_MRT_LIGHTING

#endif // IS_SHADOW_PASS
} 