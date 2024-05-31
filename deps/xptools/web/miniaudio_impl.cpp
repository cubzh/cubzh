//
//  miniaudio_impl.cpp
//  xptools-web
//
//  Created by Gaetan de Villele on 07/07/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#define STB_VORBIS_HEADER_ONLY
#include "extras/stb_vorbis.c"    /* Enables Vorbis decoding. */

// miniaudio lib
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

/* stb_vorbis implementation must come after the implementation of miniaudio. */
#undef STB_VORBIS_HEADER_ONLY
#include "extras/stb_vorbis.c"
