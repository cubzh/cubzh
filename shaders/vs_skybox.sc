$input a_position, a_texcoord0
$output v_color0, v_texcoord0
#define v_dir v_color0

/*
 * Skybox vertex shader
 */

#include "./include/bgfx.sh"
#include "./include/config.sh"
#include "./include/game_uniforms.sh"

uniform mat4 u_mtx;

void main() {
	gl_Position = mul(u_modelViewProj, vec4(a_position.xy, 0.0, 1.0));

	float fov = radians(u_fov);
	float height = tan(fov * 0.5);
	float width = height * (u_viewRect.z / u_viewRect.w);
	vec2 tex = (2.0 * a_position.zw - 1.0) * vec2(width, height);

	v_dir = mul(u_mtx, vec4(tex, 1.0, 0.0));
	v_texcoord0 = vec4(a_position.zw, a_position.xy);
}
