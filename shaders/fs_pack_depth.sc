$input v_color0
	#define v_depth v_color0.x

/*
 * Pack-depth fragment shader
 */

#include "./include/bgfx.sh"
#include "./include/utils_lib.sh"

void main() {
	float depth = fromClipSpaceDepth(v_depth);
	//float depth = fromClipSpaceDepth(gl_FragCoord.z);

	gl_FragColor = packFloatToRgba(depth);
}