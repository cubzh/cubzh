//
//  WSServer.hpp
//  xptools
//
//  Created by Gaetan de Villele on 24/02/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#pragma once

// C++
#include <cstdint>
#include <string>
#include <unordered_map>

#if defined(__VX_USE_LIBWEBSOCKETS)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wall"
#pragma clang diagnostic ignored "-Wextra"
#pragma clang diagnostic ignored "-Wdocumentation"
#include "libwebsockets.h"
#pragma clang diagnostic pop
#endif

// xptools
#include "WSTypes.hpp"
#include "WSServerConnection.hpp"

namespace vx {

///
class WSServerDelegate {
public:
    
    virtual ~WSServerDelegate();
    
    ///
    virtual bool didEstablishNewConnection(Connection_SharedPtr newIncomingConn) = 0;
    
protected:
private:
};

#if defined(__VX_USE_LIBWEBSOCKETS)

///
class WSServer final {
public:
        
    WSServer(const uint16_t listenPort,
             const bool secure,
             const std::string& tlsCertificate,
             const std::string& tlsPrivateKey);
    ~WSServer();
    
    ///
    inline void setDelegate(WSServerDelegate* wptr) {_delegate = wptr;}

    ///
    inline WSServerDelegate* getDelegate() {return _delegate;}

    ///
    void listen();
    
    ///
    void process();
    
    /// should be used only by LWS callback function
    WSServerConnection_SharedPtr* createNewConnection(WSBackend wsi);
    
    ///
    void scheduleWrite(WSServerConnection* conn);
    
    ///
    std::mutex& getContextMutex();
    
    ///
    std::vector<WSServerConnection_WeakPtr>& getActiveConnections();
    
private:
    
    // --------------------------------------------------
    // Methods
    // --------------------------------------------------
    
    // --------------------------------------------------
    // Fields
    // --------------------------------------------------
        
    ///
    uint16_t _listenPort;
    
    /// true if using wss:// instead of ws://
    bool _secure;

    /// used when operating with SSL/TLS
    std::string _tlsCertificate;

    /// used when operating with SSL/TLS
    std::string _tlsPrivateKey;

    ///
    WSServerDelegate* _delegate;
    
    /// active connections
    std::vector<WSServerConnection_WeakPtr> _activeConnections;
    
    // LWS
    struct lws_context* _lws_context;
    
    ///
    std::mutex _contextMutex;
    
    struct lws_protocol_vhost_options _lws_pvo_wsserver;
    struct lws_protocol_vhost_options _lws_pvo_options;
    struct lws_protocol_vhost_options _lws_pvo_interrupted;
    struct lws_protocol_vhost_options _lws_pvo;
    int _lws_interrupted;
    int _lws_options;
    
    ///
    int _lws_process_n;
};

#endif

}
