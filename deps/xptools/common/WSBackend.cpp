//
//  WSBackend.cpp
//  xptools
//
//  Created by Gaetan de Villele on 13/04/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#include "WSBackend.hpp"

// using namespace vx;

#if defined(__VX_USE_LIBWEBSOCKETS)

//WSBackend::WSBackend(lws* wsi) :
//_wsi(wsi) {
//
//}
//
//WSBackend::~WSBackend() {
//
//}

#else // ----- EMSCRIPTEN WEBSOCKETS API -----

#endif
