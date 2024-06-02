$input v_color0

/*
 * Pack-depth fragment shader
 */

#include "./include/bgfx.sh"
#include "./include/utils_lib.sh"

#define v_position v_color0

void main() {
	float depth = fromClipSpaceDepth(v_position.z / v_position.w);
	//float depth = fromClipSpaceDepth(gl_FragCoord.z);

	gl_FragColor = packFloatToRgba(depth);
}