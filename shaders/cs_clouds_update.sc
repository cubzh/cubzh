/*
 * Update clouds instances compute shader
 *
 * See Sky::generateClouds() for the equivalent function CPU-side
 */

#include <bgfx_compute.sh>
#include "./include/config.sh"
#include "./include/global_lighting_uniforms.sh"
#include "./include/clouds_lib.sh"

#define u_maxInvocations params[0].x
#define u_originX params[0].y
#define u_altitude params[0].z
#define u_originZ params[0].w

#define u_sampleWidth params[1].x
#define u_sampleDepth params[1].y
#define u_sampleInnerEdge params[1].z
#define u_sampleOuterEdge params[1].w

#define u_period params[2].x
#define u_magnitude params[2].y
#define u_cutout params[2].z
#define u_offset params[2].w

#define u_frequencyX params[3].x
#define u_frequencyZ params[3].y
#define u_baseScale params[3].z
#define u_maxAddScale params[3].w

#define u_baseColorR params[4].x
#define u_baseColorG params[4].y
#define u_baseColorB params[4].z
#define u_spread params[4].w

BUFFER_WO(transforms, vec4, 0);
BUFFER_RW(count, uint, 1);
BUFFER_RO(params, vec4, 2);

void resetInstance(int id) {
	int i = id * 4;
	transforms[i] 	  = vec4_splat(0.0);
	transforms[i + 1] = vec4_splat(0.0);
	transforms[i + 2] = vec4_splat(0.0);
	transforms[i + 3] = vec4_splat(0.0);
}

NUM_THREADS(COMPUTE_GROUP_SIZE, 1, 1)
void main() {
	int id = int(gl_GlobalInvocationID.x);
	int maxId = int(u_maxInvocations);

	// The following could be done in a separate "reset" compute shader...
	// 1) reset instance count
	if (id == 0) {
		atomicMin(count[0], uint(0));
	}
	// 2) reset instances transform in case indirect draw is not available,
	// - w/ indirect draw, buffer drawn with exact instance count (and compacted if occlusion culling), so this is not necessary
	// - w/o indirect draw, buffer drawn in full and the unused instances won't be visible (scale 0)
	if (id < maxId) {
		resetInstance(id);
	}

	memoryBarrierBuffer();

	if (id < maxId) {
		float totalSampleWidth = u_sampleWidth + 2.0 * u_sampleOuterEdge;

		float id_f = float(gl_GlobalInvocationID.x);
		float x = mod(id_f, totalSampleWidth) - u_sampleOuterEdge;
		float z = floor(id_f / totalSampleWidth) - u_sampleOuterEdge;

		if (x < u_sampleWidth + u_sampleOuterEdge && z < u_sampleDepth + u_sampleOuterEdge) {
			// Sample noise on the grid at provided frequencies
			float n = snoise(vec2(u_frequencyX * x, u_frequencyZ * (z + u_offset)));

			if (n >= u_cutout) {
				float edgeLength = u_sampleInnerEdge + u_sampleOuterEdge;

				// Inverse distance ratio to the outer edges ie. 1.0 = inbounds, 0.0 = outer edge
				float d = edgeLength == 0.0 ? 1.0 :
					1.0 - min(x < u_sampleInnerEdge ? u_sampleInnerEdge - x : max(x - (u_sampleWidth - u_sampleInnerEdge), 0.0),
                              z < u_sampleInnerEdge ? u_sampleInnerEdge - z : max(z - (u_sampleDepth - u_sampleInnerEdge), 0.0)) / edgeLength;
				
				
				// Instance scale variation based on:
				// - noise value diff with cutout threshold
				// - proximity to the outer edge
				float s = (u_baseScale + u_maxAddScale * CLAMP01((n - u_cutout) / (1.0 - u_cutout))) * d;

#if CLOUDS_NEAR_ZFIGHT_ENABLED
				// Add epsilon if result is near an integer value to avoid z-fighting
				s += fract(s) < CLOUDS_EPSILON ? CLOUDS_EPSILON : 0.0;
#endif

				/* uint instanceID;
				atomicFetchAndAdd(count[0], uint(1), instanceID); */
				uint instanceID = uint(id);
				atomicMax(count[0], instanceID);

				// Write instance transform, write instance color in the unused projection values
				int i = int(instanceID) * 4;
				transforms[i] 	  = vec4(s, 0.0, 0.0, u_baseColorR);
				transforms[i + 1] = vec4(0.0, s, 0.0, u_baseColorG);
				transforms[i + 2] = vec4(0.0, 0.0, s, u_baseColorB);
				transforms[i + 3] = vec4(u_originX + x * u_spread, u_altitude, u_originZ + z * u_spread, 1.0);
			}
		}
	}
}
