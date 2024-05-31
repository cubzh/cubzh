//
//  miniaudio_impl.cpp
//  xptools-windows
//
//  Created by Gaetan de Villele on 07/07/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

// miniaudio lib
#define STB_VORBIS_HEADER_ONLY
#include "extras/stb_vorbis.c"    /* Enables Vorbis decoding. */

#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

/* stb_vorbis implementation must come after the implementation of miniaudio. */
#undef STB_VORBIS_HEADER_ONLY
#include "extras/stb_vorbis.c"
