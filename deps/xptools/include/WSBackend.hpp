//
//  WSBackend.hpp
//  xptools
//
//  Created by Gaetan de Villele on 13/04/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#pragma once

#ifdef __VX_USE_LIBWEBSOCKETS
#include "libwebsockets.h"
typedef lws *WSBackend;
#endif

#ifdef __EMSCRIPTEN__
#include <emscripten/websocket.h>
typedef EMSCRIPTEN_WEBSOCKET_T WSBackend;
#endif
