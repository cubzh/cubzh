$input a_position, i_data0, i_data1, i_data2, i_data3, i_data4
#if SKY_VARIANT_MRT_LIGHTING
$output v_color0, v_texcoord0
	#define v_normal v_texcoord0.xyz
	#define v_linearDepth v_texcoord0.w
#else
$output v_color0
#endif

#include "./include/bgfx.sh"
#include "./include/config.sh"
#include "./include/game_uniforms.sh"
#include "./include/global_lighting_uniforms.sh"

#if !SKY_VARIANT_COMPUTE
uniform vec4 u_staticCloudsParams[3];

#define u_speed u_staticCloudsParams[0].x
#define u_totalDepth u_staticCloudsParams[0].y
#define u_outerEdge u_staticCloudsParams[0].z
#define u_originX u_staticCloudsParams[0].w

#define u_altitude u_staticCloudsParams[1].x
#define u_originZ u_staticCloudsParams[1].y
#define u_baseColorR u_staticCloudsParams[1].z
#define u_baseColorG u_staticCloudsParams[1].w

#define u_baseColorB u_staticCloudsParams[2].x
#endif

void main() {
	// We use projection values to store instance color
#if SKY_VARIANT_COMPUTE
	vec3 base = vec3(i_data0.w, i_data1.w, i_data2.w);
#else
	vec3 base = vec3(u_baseColorR, u_baseColorG, u_baseColorB);
#endif

	// Clouds color blends with background (sky color)
	vec3 lit = mix(base, u_skyColor.xyz, CLOUDS_BLEND_COLOR);

	// Instance model mtx 
	mat4 model;
	model[0] = vec4(i_data0.xyz, 0.0);
	model[1] = vec4(i_data1.xyz, 0.0);
	model[2] = vec4(i_data2.xyz, 0.0);
#if SKY_VARIANT_COMPUTE
	model[3] = i_data3;
#else
	float z = mod(u_outerEdge + i_data3.z - u_speed * u_time, u_totalDepth) - u_outerEdge;
	model[3] = vec4(u_originX + i_data3.x , u_altitude, u_originZ + z, i_data3.w);
#endif

	vec4 world = instMul(model, vec4(a_position.xyz, 1.0));
#if SKY_VARIANT_MRT_LIGHTING && SKY_VARIANT_MRT_LINEAR_DEPTH
	vec4 view = mul(u_view, world);
#endif

	gl_Position = mul(u_viewProj, world);
	v_color0 = vec4(lit, 1.0);
#if SKY_VARIANT_MRT_LIGHTING
	v_normal = vec3(LIGHT_FRAGMENT_TRANSLUCENT, CLOUDS_TRANSLUCENCY);
#if SKY_VARIANT_MRT_LINEAR_DEPTH
	v_linearDepth = view.z;
#endif
#endif
}
