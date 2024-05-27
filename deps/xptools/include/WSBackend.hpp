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

// `WSBackend` is `pointer to lws`
typedef lws *WSBackend;

//namespace vx {
//
//class WSBackend {
//
//public:
//
//    WSBackend(lws* wsi);
//    ~WSBackend();
//
//    // LWS connection handle
//    lws* _wsi;
//
//private:
//
//};
//
//}

#else // EMSCRIPTEN WEBSOCKET API ----------------------------------------------

#include <emscripten/websocket.h>

typedef EMSCRIPTEN_WEBSOCKET_T WSBackend;

//namespace vx {
//
//class WSBackend {
//
//public:
//
//    // emscripten connection handle
//    // TODO: !
//    int _wsi;
//
//private:
//
//};
//
//}

#endif
