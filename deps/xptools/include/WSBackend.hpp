//
//  WSBackend.hpp
//  xptools
//
//  Created by Gaetan de Villele on 13/04/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#pragma once

#if defined(__VX_USE_LIBWEBSOCKETS)
#include "libwebsockets.h"
typedef lws *WSBackend;
#endif

#if defined(__VX_PLATFORM_WASM)
#include <emscripten/websocket.h>
typedef EMSCRIPTEN_WEBSOCKET_T WSBackend;
#endif
