//
//  miniaudio_impl.mm
//  xptools-ios
//
//  Created by Gaetan de Villele on 07/07/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#import <Foundation/Foundation.h>

// miniaudio lib
#define STB_VORBIS_HEADER_ONLY
#include "extras/stb_vorbis.c"    /* Enables Vorbis decoding. */

#ifdef  __APPLE__
#define MA_NO_RUNTIME_LINKING
#endif

#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

/* stb_vorbis implementation must come after the implementation of miniaudio. */
#undef STB_VORBIS_HEADER_ONLY
#include "extras/stb_vorbis.c"
