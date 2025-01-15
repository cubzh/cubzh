#if MESH_VARIANT_MRT_LIGHTING
$input v_color0, v_texcoord0, v_texcoord1
    #define v_uv v_texcoord0.xy
    #define v_linearDepth v_texcoord0.z
    #define v_normal v_texcoord1.xyz
#else
$input v_color0, v_texcoord0
    #define v_uv v_texcoord0.xy
#endif

#include "./include/bgfx.sh"
#include "./include/config.sh"
#include "./include/utils_lib.sh"

#if MESH_VARIANT_MRT_LIGHTING
uniform vec4 u_lighting;
#endif

void main() {
    vec4 color = v_color0;

#if MESH_VARIANT_ALPHA == 0
    color.a = 1.0;
#endif

#if MESH_VARIANT_MRT_LIGHTING
    gl_FragData[0] = color;
    gl_FragData[1] = vec4(encodeNormalUint(v_normal), LIGHTING_LIT_FLAG);
    gl_FragData[2] = vec4(u_lighting.yzw * VOXEL_LIGHT_RGB_PRE_FACTOR, u_lighting.x);
    gl_FragData[3] = vec4(u_lighting.yzw * VOXEL_LIGHT_RGB_POST_FACTOR, LIGHTING_LIT_FLAG);
#if MESH_VARIANT_MRT_LINEAR_DEPTH
    gl_FragData[4] = vec4_splat(v_linearDepth);
#endif
#else
    gl_FragColor = color;
#endif
} 