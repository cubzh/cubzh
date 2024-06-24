#ifndef __QUAD_LIB_SH__
#define __QUAD_LIB_SH__

#include "./config.sh"

void unpackQuadFullMetadata(float f, out float metadata[6]) {
	float unpack = f;
	float b = floor((unpack + UNPACK_FUDGE) / 16384.0);
	unpack -= b * 16384.0;
	float g = floor((unpack + UNPACK_FUDGE) / 1024.0);
	unpack -= g * 1024.0;
	float r = floor((unpack + UNPACK_FUDGE) / 64.0);
	unpack -= r * 64.0;
	float s = floor((unpack + UNPACK_FUDGE) / 4.0);
	unpack -= s * 4.0;
	float unpack9SliceNormal = floor((unpack + UNPACK_FUDGE) / 2.0);
	float unlit = unpack - unpack9SliceNormal * 2.0;

	metadata[0] = unlit;
	metadata[1] = unpack9SliceNormal;
	metadata[2] = s / VOXEL_LIGHT_MAX;
	metadata[3] = r / VOXEL_LIGHT_MAX;
	metadata[4] = g / VOXEL_LIGHT_MAX;
	metadata[5] = b / VOXEL_LIGHT_MAX;
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