//
//  WSService.hpp
//  xptools
//
//  Created by Gaetan de Villele on 20/03/2022.
//

#pragma once

// C++
#include <thread>
#include <unordered_set>
#include <unordered_map>

// websockets
#if defined(__VX_USE_LIBWEBSOCKETS)
// libwebsockets
#include "libwebsockets.h"
#else
// emscripten API
// TODO: gdevillele: !!!
#endif

// xptools
#include "Channel.hpp"
#include "HttpRequest.hpp"
#include "WSConnection.hpp"

// Websocket protocols for Particubes
#define P3S_LWS_PROTOCOL_HTTP "http"
#define P3S_LWS_PROTOCOL_WS_JOIN "join"
#define P3S_LWS_PROTOCOL_COUNT 2

namespace vx {

class WSService final {

public:
    
    // Types
    
    /// per virtual host data struct
    struct ws_vhd {
        struct lws_context *context;
        struct lws_vhost *vhost;
        vx::WSService* wsservice;
    };
    
    ///
    static WSService* shared();
    
    ///
    ~WSService();
    
    ///
    void sendHttpRequest(HttpRequest_SharedPtr httpReq);

    ///
    void cancelHttpRequest(HttpRequest_SharedPtr httpReq);
    
    ///
    void requestWSConnection(WSConnection_SharedPtr wsConn);
    
    ///
    void scheduleWSConnectionWrite(WSConnection_SharedPtr wsConn);
    
#if defined(__VX_USE_LIBWEBSOCKETS)
    ///
    std::vector<WSConnection_WeakPtr>& getWSConnectionsActive();

    ///
    const std::vector<lws_token_indexes>& getHeadersToParse();
#endif
    
private:
    
    /// singleton shared instance
    static WSService *_sharedInstance;
    
    ///
    WSService();
    
    // methods
    
    ///
    void _init();
    
    ///
    void _serviceThreadFunction();
    
    // fields
    
#if defined(__VX_USE_LIBWEBSOCKETS)

    ///
    std::vector<lws_token_indexes> _headersToParse;

    /// requests waiting to be sent
    Channel<HttpRequest_SharedPtr> _httpRequestWaitingQueue;

    /// WSConnections requests waiting to be sent
    Channel<WSConnection_SharedPtr> _wsConnectionWaitingQueue;
    
    /// WSConnections currently active
    std::vector<WSConnection_WeakPtr> _wsConnectionsActive;

#else // EMSCRIPTEN
    
    /// pending WSConnections (used to retain shared_ptrs)
    /// (used only on WASM)
    std::unordered_set<WSConnection_SharedPtr> _wsConnections;
    
#endif
    
    ///
    std::mutex _wsiNotifyMutex;
    
    ///
    std::thread _serviceThread;
    
    ///
    bool _serviceThreadInterrupted;
    
    ///
    std::mutex _serviceThreadInterruptedMutex;
    
    ///
    struct lws_protocols **_lws_protocols;

    ///
    struct lws_context *_lws_context;
    
    ///
    bool _contextReady;
    
    /// Mutex to protect accesses to:
    /// _contextReady
    /// lws_cancel_service calls
    std::mutex _contextMutex;
};

} // namespace vx
