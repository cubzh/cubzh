#ifndef __GRID_LIB_SH__
#define __GRID_LIB_SH__

#include "./utils_lib.sh"

// Ref: legacy metal shader (metal_grid.metal)! :)
// Adapted a bit, removed branching, and made it consistent with the arbitrary scales of our scene
vec4 getGridColor(vec3 model, vec4 baseColor, vec3 gridColor, float scaleMag, float depth) {
	float d = safe_divide(depth, scaleMag);
	float epsilon = GRID_THICKNESS_FACTOR * d;
	float nepsilon = 1.0 - epsilon;
	vec3 f = fract(model);

	// Can't use vec here, for some reason bgfx/shaderc patches that for GLES using an invalid syntax
	float gridCheckX = float(f.x <= epsilon || f.x >= nepsilon);
	float gridCheckY = float(f.y <= epsilon || f.y >= nepsilon);
	float gridCheckZ = float(f.z <= epsilon || f.z >= nepsilon);
	float isOnGrid = step (2, gridCheckX + gridCheckY + gridCheckZ);

	return mix(
		baseColor,
		mix(vec4(gridColor, 1.0), baseColor, CLAMP01((d - GRID_FADE_DISTANCE) / GRID_FADE_LENGTH)),
		isOnGrid
	);
}

#endif // __GRID_LIB_SH__
