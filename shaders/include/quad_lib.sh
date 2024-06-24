#ifndef __QUAD_LIB_SH__
#define __QUAD_LIB_SH__

#include "./config.sh"

void unpackQuadFullMetadata(float f, out float metadata[5]) {
	float unpack = f;
	float b = floor((unpack + UNPACK_FUDGE) / 8192.0);
	unpack -= b * 8192.0;
	float g = floor((unpack + UNPACK_FUDGE) / 512.0);
	unpack -= g * 512.0;
	float r = floor((unpack + UNPACK_FUDGE) / 32.0);
	unpack -= r * 32.0;
	float s = floor((unpack + UNPACK_FUDGE) / 2.0);
	float unlit = unpack - s * 2.0;

	metadata[0] = unlit;
	metadata[1] = s / VOXEL_LIGHT_MAX;
	metadata[2] = r / VOXEL_LIGHT_MAX;
	metadata[3] = g / VOXEL_LIGHT_MAX;
	metadata[4] = b / VOXEL_LIGHT_MAX;
}

float sliceUV(float uv, vec2 borders, float slice) {
	if (uv < borders[0]) {
		return uv / borders[0] * slice;
	} else if (uv > borders[1]) {
		return slice + (uv - borders[1]) / (1.0 - borders[1]) * (1.0 - slice);
	} else {
		return slice;
	}
}

#endif // __QUAD_LIB_SH__