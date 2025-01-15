#define IS_SHADOW_PASS (MESH_VARIANT_MRT_SHADOW_PACK || MESH_VARIANT_MRT_SHADOW_SAMPLE)

$input a_position, a_normal, a_texcoord0, a_color0
#if IS_SHADOW_PASS

#if MESH_VARIANT_MRT_SHADOW_PACK
$output v_color0
	#define v_depth v_color0.x
#endif

#else // IS_SHADOW_PASS

#if MESH_VARIANT_MRT_LIGHTING
$output v_color0, v_texcoord0, v_texcoord1
    #define v_uv v_texcoord0.xy
	#define v_linearDepth v_texcoord0.z
	#define v_normal v_texcoord1.xyz
#else
$output v_color0, v_texcoord0
    #define v_uv v_texcoord0.xy
#endif

#endif // IS_SHADOW_PASS

#include "./include/bgfx.sh"

void main() {
    vec4 model = vec4(a_position.xyz, 1.0);
    vec4 clip = mul(u_modelViewProj, model);

#if IS_SHADOW_PASS

    gl_Position = clip;
#if MESH_VARIANT_MRT_SHADOW_PACK
    v_depth = clip.z / clip.w;
#endif

#else // IS_SHADOW_PASS

#if MESH_VARIANT_MRT_LINEAR_DEPTH
    vec4 view = mul(u_modelView, model);
#endif
    
    gl_Position = clip;
    v_color0 = a_color0;
    v_uv = a_texcoord0.xy;
#if MESH_VARIANT_MRT_LIGHTING
#if MESH_VARIANT_MRT_LINEAR_DEPTH
    v_linearDepth = view.z;
#endif
    v_normal = a_normal;
#endif // MESH_VARIANT_MRT_LIGHTING

#endif // IS_SHADOW_PASS
} 