#ifndef __FONT_LIB_SH__
#define __FONT_LIB_SH__

#include "./config.sh"

vec2 unpackFontMetadata(float f) {
	float unpack = f * 32767.0;
	float filtering = floor((unpack + UNPACK_FUDGE) / 2.0);
	float colored = unpack - filtering * 2.0;

	return vec2(colored, filtering);
}

#endif // __FONT_LIB_SH__