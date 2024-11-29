//
//  WSServer.cpp
//  xptools
//
//  Created by Gaetan de Villele on 24/02/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#include "WSServer.hpp"

// C++
#include <algorithm>
#include <cassert>

// xptools
#include "vxlog.h"
#include "WSServerConnection.hpp"

#define PROTOCOL_NAME "join"
#define WS_SERVER_RX_BUFFER_SIZE 1024
#define WS_WRITE_BUF_SIZE 512 // arbitrary size

using namespace vx;

#if defined(__VX_USE_LIBWEBSOCKETS)

//
// functions' prototypes
//

static int lws_callback(struct lws *wsi,
                        enum lws_callback_reasons reason,
                        void *user,
                        void *in,
                        size_t len);

// one of these created for each message
struct msg {
    void *payload; // is malloc'd
    size_t len;
    char binary;
    char first;
    char final;
};


// per-connection data struct
struct vhd_minimal_server_echo {
    struct lws_context *context;
    struct lws_vhost *vhost;

    int *interrupted;
    int *options;

    vx::WSServer* wsserver;
};

#endif

// --------------------------------------------------
//
// MARK: - WSServerDelegate -
//
// --------------------------------------------------

WSServerDelegate::~WSServerDelegate() {}

// --------------------------------------------------
//
// MARK: - WSServer -
//
// --------------------------------------------------

#if defined(__VX_USE_LIBWEBSOCKETS)

WSServer::WSServer(const uint16_t listenPort,
                   const bool secure,
                   const std::string& tlsCertificate,
                   const std::string& tlsPrivateKey):
_listenPort(listenPort),
_secure(secure),
_tlsCertificate(tlsCertificate),
_tlsPrivateKey(tlsPrivateKey),
_delegate(nullptr),
_activeConnections(),
_lws_context(nullptr),
_contextMutex(),
_lws_pvo_wsserver(),
_lws_pvo_options(),
_lws_pvo_interrupted(),
_lws_pvo(),
_lws_interrupted(0),
_lws_options(0),
_lws_process_n(0) {

    // pvo
    _lws_pvo_wsserver = {
        nullptr,
        nullptr,
        "wsserver", // pvo name
        reinterpret_cast<const char *>(this) // pvo value
    };

    _lws_pvo_options = {
        &_lws_pvo_wsserver,
        nullptr,
        "options", // pvo name
        reinterpret_cast<const char *>(&_lws_options) // pvo value
    };

    _lws_pvo_interrupted = {
        &_lws_pvo_options,
        nullptr,
        "interrupted", // pvo name
        reinterpret_cast<const char *>(&_lws_interrupted) // pvo value
    };

    _lws_pvo = {
        nullptr,                      // "next" pvo linked-list
        &_lws_pvo_interrupted,        // "child" pvo linked-list
        PROTOCOL_NAME,                // protocol name we belong to on this vhost
        ""                            // ignored
    };
}

WSServer::~WSServer() {
    if (_lws_context != nullptr) {
        lws_context_destroy(_lws_context);
    }
}

#define LWS_PLUGIN_PROTOCOL_PARTICUBES_JOIN \
{ \
PROTOCOL_NAME, \
lws_callback, \
0, \
WS_SERVER_RX_BUFFER_SIZE, \
0, NULL, 0 \
}

static struct lws_protocols protocols[] = {
    LWS_PLUGIN_PROTOCOL_PARTICUBES_JOIN,
    LWS_PROTOCOL_LIST_TERM
};

void WSServer::listen() {
    vxlog_trace("[WSServer] start listening... %d %s", _listenPort, _secure ? "(wss)" : "(ws)");

    // const int protoCount = 1;
    // const int arraySize = protoCount + 1;
    // struct lws_protocols** protocols = reinterpret_cast<struct lws_protocols**>(malloc(sizeof(struct lws_protocols*) * arraySize));

    struct lws_context_creation_info info;

    /* for LLL_ verbosity above NOTICE to be built into lws,
     * lws must have been configured and built with
     * -DCMAKE_BUILD_TYPE=DEBUG instead of =RELEASE */
    /* | LLL_INFO */ /* | LLL_PARSER */ /* | LLL_HEADER */
    /* | LLL_EXT */ /* | LLL_CLIENT */ /* | LLL_LATENCY */
    /* | LLL_DEBUG */;
    const int logs = 0; // LLL_USER | LLL_ERR | LLL_WARN | LLL_NOTICE
    lws_set_log_level(logs, nullptr);

    lwsl_user("LWS minimal ws client echo + permessage-deflate + multifragment bulk message\n");
    lwsl_user("   lws-minimal-ws-client-echo [-n (no exts)] [-p port] [-o (once)]\n");

    memset(&info, 0, sizeof info); /* otherwise uninitialized garbage */
    info.port = _listenPort;
    info.protocols = protocols;
    info.pvo = &_lws_pvo;
    info.pt_serv_buf_size = 32 * 1024;
    info.options = (LWS_SERVER_OPTION_VALIDATE_UTF8 |
                    LWS_SERVER_OPTION_HTTP_HEADERS_SECURITY_BEST_PRACTICES_ENFORCE);
    if (_secure) {
        info.options |= LWS_SERVER_OPTION_DO_SSL_GLOBAL_INIT;
#if defined(ONLINE_GAMESERVER)
        if (_tlsCertificate.empty() == false) {
            info.server_ssl_cert_mem = _tlsCertificate.c_str();
            info.server_ssl_cert_mem_len = static_cast<int>(_tlsCertificate.length());
        }
        if (_tlsPrivateKey.empty() == false) {
            info.server_ssl_private_key_mem = _tlsPrivateKey.c_str();
            info.server_ssl_private_key_mem_len = static_cast<int>(_tlsPrivateKey.length());
        }
#endif
    }
    
    // should be dynamic, later... or maybe we should remove it altogether
    // info.vhost_name = "servers-eu-1.cu.bzh";

    // TCP keep-alive
    // info.ka_time = 500; // 500sec
    // info.ka_probes = 20; // nb of retries
    // info.ka_interval = 5; // interval between retries

    _lws_context = lws_create_context(&info);
    if (_lws_context == nullptr) {
        vxlog_error("[WSServer::listen] lws init failed");
    }
//    else {
//        while (n >= 0 && !_lws_interrupted) {
//            n = lws_service(context, 0);
//        }
//
//        lws_context_destroy(context);
//
//        lwsl_user("Completed %s\n", interrupted == 2 ? "OK" : "failed");
//    }
}

void WSServer::process() {
    if (_lws_process_n >= 0 && _lws_interrupted == false) {
        _lws_process_n = lws_service(_lws_context, 0);
    }
}

// Allocates new connection and notify delegates
WSServerConnection_SharedPtr* WSServer::createNewConnection(WSBackend wsi) {
    if (wsi == nullptr) {
        return nullptr;
    }

    // TODO: remove 2nd argument
    WSServerConnection *newConnPtr = new WSServerConnection(this, wsi);
    if (newConnPtr == nullptr) {
        return nullptr;
    }

    WSServerConnection_SharedPtr *conn = new WSServerConnection_SharedPtr(newConnPtr);
    if (conn == nullptr) {
        delete newConnPtr;
        return nullptr;
    }

    // add new connection to the collection of active connections
    _activeConnections.push_back(WSServerConnection_WeakPtr(*conn));

    return conn;
}

void WSServer::scheduleWrite(WSServerConnection* conn) {
    if (conn == nullptr) {
        vxlog_error("[WSServer::scheduleWrite] connection is NULL");
        return;
    }

    // if this connection is already writing, we don't need to trigger the
    // lws "writable" callback.
    if (conn->isWriting() == true) {
        return;
    }

    //
    lws* wsi = conn->getWsi();
    if (wsi == nullptr) {
        vxlog_error("[WSServer::scheduleWrite] connection is NULL");
        return;
    }
    {
        std::lock_guard<std::mutex> lock(_contextMutex);
        lws_cancel_service_pt(wsi);
    }
}

std::mutex& WSServer::getContextMutex() {
    return _contextMutex;
}

std::vector<WSServerConnection_WeakPtr>& WSServer::getActiveConnections() {
    return _activeConnections;
}

// --------------------------------------------------
//
// MARK: - Private -
//
// --------------------------------------------------



// --------------------------------------------------
//
// MARK: - LWS C Code -
//
// --------------------------------------------------

static std::string reasonToString(const int reason) {
    switch (reason) {
        case LWS_CALLBACK_ESTABLISHED:
            return "LWS_CALLBACK_ESTABLISHED";
        case LWS_CALLBACK_CLOSED_HTTP:
            return "LWS_CALLBACK_CLOSED_HTTP";
        case LWS_CALLBACK_RECEIVE:
            return "LWS_CALLBACK_RECEIVE";
        case LWS_CALLBACK_SERVER_WRITEABLE:
            return "LWS_CALLBACK_SERVER_WRITEABLE";
        case LWS_CALLBACK_CLOSED:
            return "LWS_CALLBACK_CLOSED";
        case LWS_CALLBACK_PROTOCOL_INIT:
            return "LWS_CALLBACK_PROTOCOL_INIT";
        case LWS_CALLBACK_PROTOCOL_DESTROY:
            return "LWS_CALLBACK_PROTOCOL_DESTROY";
        case LWS_CALLBACK_EVENT_WAIT_CANCELLED:
            return "LWS_CALLBACK_EVENT_WAIT_CANCELLED";
        case LWS_CALLBACK_OPENSSL_LOAD_EXTRA_SERVER_VERIFY_CERTS:
            return "LWS_CALLBACK_OPENSSL_LOAD_EXTRA_SERVER_VERIFY_CERTS";
        case LWS_CALLBACK_OPENSSL_LOAD_EXTRA_CLIENT_VERIFY_CERTS:
            return "LWS_CALLBACK_OPENSSL_LOAD_EXTRA_CLIENT_VERIFY_CERTS";
        case LWS_CALLBACK_CLIENT_FILTER_PRE_ESTABLISH:
            return "LWS_CALLBACK_CLIENT_FILTER_PRE_ESTABLISH";
        case LWS_CALLBACK_FILTER_NETWORK_CONNECTION:
            return "LWS_CALLBACK_FILTER_NETWORK_CONNECTION";
        case LWS_CALLBACK_SERVER_NEW_CLIENT_INSTANTIATED:
            return "LWS_CALLBACK_SERVER_NEW_CLIENT_INSTANTIATED";
        case LWS_CALLBACK_FILTER_PROTOCOL_CONNECTION:
            return "LWS_CALLBACK_FILTER_PROTOCOL_CONNECTION";
        case LWS_CALLBACK_WSI_CREATE:
            return "LWS_CALLBACK_WSI_CREATE";
        case LWS_CALLBACK_WSI_DESTROY:
            return "LWS_CALLBACK_WSI_DESTROY";
        case LWS_CALLBACK_GET_THREAD_ID:
            return "LWS_CALLBACK_GET_THREAD_ID";
        case LWS_CALLBACK_CLOSED_CLIENT_HTTP:
            return "LWS_CALLBACK_CLOSED_CLIENT_HTTP";
        case LWS_CALLBACK_HTTP_BIND_PROTOCOL:
            return "LWS_CALLBACK_HTTP_BIND_PROTOCOL";
        case LWS_CALLBACK_ADD_HEADERS:
            return "LWS_CALLBACK_ADD_HEADERS";
        case LWS_CALLBACK_CLIENT_HTTP_BIND_PROTOCOL:
            return "LWS_CALLBACK_CLIENT_HTTP_BIND_PROTOCOL";
        case LWS_CALLBACK_HTTP_CONFIRM_UPGRADE:
            return "LWS_CALLBACK_HTTP_CONFIRM_UPGRADE";
        case LWS_CALLBACK_VHOST_CERT_AGING:
            return "LWS_CALLBACK_VHOST_CERT_AGING";
        case LWS_CALLBACK_CLIENT_HTTP_DROP_PROTOCOL:
            return "LWS_CALLBACK_CLIENT_HTTP_DROP_PROTOCOL";
        case LWS_CALLBACK_WS_SERVER_DROP_PROTOCOL:
            return "LWS_CALLBACK_WS_SERVER_DROP_PROTOCOL";
        case LWS_CALLBACK_WS_CLIENT_DROP_PROTOCOL:
            return "LWS_CALLBACK_WS_CLIENT_DROP_PROTOCOL";
        case LWS_CALLBACK_CONNECTING:
            return "LWS_CALLBACK_CONNECTING";
        default:
            return "<UNKNOWN_REASON>";
    }
}

static int lws_callback(struct lws *wsi,
                        enum lws_callback_reasons reason,
                        void *user,
                        void *in,
                        size_t len) {
    vxlog_trace("[WSServer] lws_callback: %s", reasonToString(reason).c_str());
    
    struct vhd_minimal_server_echo *vhd = reinterpret_cast<struct vhd_minimal_server_echo *>(lws_protocol_vh_priv_get(lws_get_vhost(wsi), lws_get_protocol(wsi)));

    WSServerConnection_SharedPtr conn = nullptr;
    switch (reason) {
        case LWS_CALLBACK_ESTABLISHED:
        case LWS_CALLBACK_RECEIVE:
        case LWS_CALLBACK_SERVER_WRITEABLE:
        case LWS_CALLBACK_CLOSED: {
            if (user != nullptr) {
                conn = *(reinterpret_cast<WSServerConnection_SharedPtr*>(user));
                if (conn->isClosed()) { // could have been cancelled
                    delete reinterpret_cast<WSServerConnection_SharedPtr*>(user);
                    lws_set_wsi_user(wsi, nullptr);
                    return -1;
                }
            }
            break;
        }
        default:
            break;
    }

    switch (reason) {
        case LWS_CALLBACK_PROTOCOL_INIT: {
            // vxlog_debug("[WSServer] LWS_CALLBACK_PROTOCOL_INIT");
            // this is called once per protocol/vhost (incoming connection) tuple
            vhd = reinterpret_cast<struct vhd_minimal_server_echo *>(lws_protocol_vh_priv_zalloc(lws_get_vhost(wsi),
                                                                                                 lws_get_protocol(wsi),
                                                                                                 sizeof(struct vhd_minimal_server_echo)));
            if (vhd == nullptr) {
                return -1;
            }

            vhd->context = lws_get_context(wsi);
            vhd->vhost = lws_get_vhost(wsi);

            // get the pointers we were passed in pvo
            const struct lws_protocol_vhost_options *pvo = reinterpret_cast<const struct lws_protocol_vhost_options *>(in);
            vhd->interrupted = const_cast<int*>(reinterpret_cast<const int*>(lws_pvo_search(pvo, "interrupted")->value));
            vhd->options = const_cast<int*>(reinterpret_cast<const int*>(lws_pvo_search(pvo, "options")->value));
            vhd->wsserver = const_cast<vx::WSServer*>(reinterpret_cast<const vx::WSServer*>(lws_pvo_search(pvo, "wsserver")->value));
            break;
        }
        case LWS_CALLBACK_PROTOCOL_DESTROY: {
            // WSSERVICE_DEBUG_LOG("⚡️ [WSServer] LWS_CALLBACK_PROTOCOL_DESTROY");
            // no need to free the buffer allocated using lws_protocol_vh_priv_zalloc
            // it's done automatically
            break;
        }
        case LWS_CALLBACK_EVENT_WAIT_CANCELLED: {

            if (vhd != nullptr && vhd->wsserver != nullptr) {
                std::vector<WSServerConnection_WeakPtr>& conns = vhd->wsserver->getActiveConnections();
                std::vector<WSServerConnection_WeakPtr>::iterator it;

                // remove expired weak pointers
                conns.erase(std::remove_if(conns.begin(), conns.end(), [](WSServerConnection_WeakPtr ptr){
                    return ptr.expired();
                }), conns.end());

                // loop over active connections and call `lws_callback_on_writable` if necessary
                for (it = conns.begin(); it != conns.end(); it++) {
                    WSServerConnection_SharedPtr strong = (*it).lock();
                    if (strong == nullptr) { continue; }
                    if (strong->doneWriting() == false) {
                        strong->setIsWriting(true);
                        // request additional write callback
                        lws_callback_on_writable(strong->getWsi());
                    }
                }
            }
            break;
        }
        case LWS_CALLBACK_OPENSSL_LOAD_EXTRA_SERVER_VERIFY_CERTS: {
            break;
        }
        case LWS_CALLBACK_OPENSSL_LOAD_EXTRA_CLIENT_VERIFY_CERTS: {
            break;
        }
        case LWS_CALLBACK_ESTABLISHED: {
            // vxlog_debug("[WSServer] LWS_CALLBACK_ESTABLISHED");
            // create WSServerConnection object (this notifies the delegates)
            WSServerConnection_SharedPtr* connPtr = vhd->wsserver->createNewConnection(wsi);
            if (connPtr == nullptr) {
                vxlog_error("LWS_CALLBACK_ESTABLISHED : failed to create new connection");
                return -1;
            }

            // notify WSServerDelegate of the new connection
            WSServerDelegate *wssDelegate = vhd->wsserver->getDelegate();
            if (wssDelegate != nullptr) {
                if (wssDelegate->didEstablishNewConnection(*connPtr) == false) {
                    // TODO: what should we do in that case?
                    // It could mean no ID available
                    // We should close but ideally indicating the server is full
                    // NOTE: connPtr needs to be freed at some point
                    // NOTE2: connection should be removed from active connections
                }
            }

            // notify Connection's delegate
            std::shared_ptr<ConnectionDelegate> connDelegate = (*connPtr)->getDelegate().lock();
            if (connDelegate != nullptr) {
                connDelegate->connectionDidEstablish(*(connPtr->get()));
            }

            // store connection reference into the wsi
            lws_set_wsi_user(wsi, connPtr);
            break;
        }

        case LWS_CALLBACK_RECEIVE: {
            // this callback can be called multiple times for a single message
            // receive (when the message is larger than WS_SERVER_RX_BUFFER_SIZE)
            
//            lwsl_user("LWS_CALLBACK_RECEIVE: %4d (rpp %5d, first %d, "
//                      "last %d, bin %d (+ %d = %d))\n",
//                      static_cast<int>(len),
//                      static_cast<int>(lws_remaining_packet_payload(wsi)),
//                      lws_is_first_fragment(wsi),
//                      lws_is_final_fragment(wsi),
//                      lws_frame_is_binary(wsi),
//                      static_cast<int>(len), // count of new bytes being received
//                      static_cast<int>(pss->msglen) + static_cast<int>(len));
            
            const bool isFinalFragment = lws_is_final_fragment(wsi) != 0;

            if (conn != nullptr) {
                conn->receivedBytes(reinterpret_cast<char*>(in), len, isFinalFragment);
            } else {
                vxlog_error("LWS_CALLBACK_RECEIVE : conn is NULL");
            }

            break;
        }
        case LWS_CALLBACK_SERVER_WRITEABLE: {
            // vxlog_debug("[WSServer] LWS_CALLBACK_SERVER_WRITEABLE");
            if (conn != nullptr) {
                if (conn->doneWriting() == false) {

                    static char buf[LWS_PRE + WS_WRITE_BUF_SIZE];
                    char *start = &(buf[LWS_PRE]); // buf + LWS_PRE

                    bool firstFragment;
                    bool partial;
                    const size_t len_to_write = conn->write(start, WS_WRITE_BUF_SIZE, firstFragment, partial);

                    int writeMode = 0;
                    // vxlog_debug("WS write: --- %d/%d - writing %d", alreadyWritten, totalPayloadLen, len_to_write);
                    if (firstFragment) {
                        // first write for this payload
                        if (partial == false) {
                            // vxlog_debug("WS write: single frame, no fragmentation");
                            writeMode = LWS_WRITE_BINARY; // single frame, no fragmentation
                        } else {
                            // vxlog_debug("WS write: first fragment");
                            writeMode = LWS_WRITE_BINARY | LWS_WRITE_NO_FIN; // first fragment
                        }
                    } else {
                        if (partial == true) {
                            // vxlog_debug("WS write: middle fragment");
                            writeMode = LWS_WRITE_CONTINUATION | LWS_WRITE_NO_FIN; // all middle fragments
                        } else {
                            // vxlog_debug("WS write: last fragment");
                            writeMode = LWS_WRITE_CONTINUATION; // last fragment
                        }
                    }
                    lws_write_protocol wp = static_cast<lws_write_protocol>(writeMode);

                    const int bytesJustWritten = lws_write(wsi,
                                                           reinterpret_cast<uint8_t *>(start),
                                                           len_to_write,
                                                           wp);

                    if (bytesJustWritten < static_cast<int>(len_to_write)) {
                        // Error, connection is dead.
                        return 1;
                    }

                    if (conn->doneWriting() == false) {
                        std::lock_guard<std::mutex> lock(vhd->wsserver->getContextMutex());
                        lws_callback_on_writable(wsi); // request additional write
                        assert(conn->isWriting() == true);
                    } else {
                        conn->setIsWriting(false);
                    }
                }
            } else {
                vxlog_error("[WSServer] LWS_CALLBACK_SERVER_WRITEABLE : conn is NULL");
            }
            break;
        }
        case LWS_CALLBACK_CLOSED: {
            // vxlog_debug("[WSServer] LWS_CALLBACK_CLOSED");
            if (conn != nullptr) {
                conn->close();
                // delete the WSServerConnection_SharedPtr
                delete reinterpret_cast<WSServerConnection_SharedPtr*>(user);
                // release shared_ptr
                lws_set_wsi_user(wsi, nullptr);
                // destroy this wsi
                return -1;
            } else {
                vxlog_error("[WSServer] LWS_CALLBACK_CLOSED : conn is NULL");
            }
            break;
        }
        case LWS_CALLBACK_CLIENT_FILTER_PRE_ESTABLISH: // 2
        case LWS_CALLBACK_CLOSED_HTTP: // 5
        case LWS_CALLBACK_FILTER_NETWORK_CONNECTION: // 17
        case LWS_CALLBACK_SERVER_NEW_CLIENT_INSTANTIATED: // 19
        case LWS_CALLBACK_FILTER_PROTOCOL_CONNECTION: // 20
        case LWS_CALLBACK_WSI_CREATE: // 29
        case LWS_CALLBACK_WSI_DESTROY: // 30
        case LWS_CALLBACK_GET_THREAD_ID: // 31
        case LWS_CALLBACK_ESTABLISHED_CLIENT_HTTP: // 44
        case LWS_CALLBACK_CLOSED_CLIENT_HTTP: // 45
        case LWS_CALLBACK_HTTP_BIND_PROTOCOL: // 49
        case LWS_CALLBACK_ADD_HEADERS: // 53
        case LWS_CALLBACK_CLIENT_HTTP_BIND_PROTOCOL: // 85
        case LWS_CALLBACK_HTTP_CONFIRM_UPGRADE: // 86
        case LWS_CALLBACK_VHOST_CERT_AGING: // 72
        case LWS_CALLBACK_CLIENT_HTTP_DROP_PROTOCOL: // 76
        case LWS_CALLBACK_WS_SERVER_DROP_PROTOCOL: // 78
        case LWS_CALLBACK_WS_CLIENT_DROP_PROTOCOL: // 80
        case LWS_CALLBACK_CONNECTING: // 105
            // Nothing to do but keeping empty cases on purpose
            break;

        default:
            vxlog_error("lws_callback case not handled: %d", reason);

            // TODO: disconnect gracefully
            //pss = dynamic_cast<struct per_session_data *>(user); // per_session_data would have to be class to do this
            //if (pss != nullptr) {
            //    WSConnectionID connID = pss->connectionID;
            //    WSServerConnection_SharedPtr conn = vhd->wsserver->getConnectionByID(connID);
            //    if (conn != nullptr) {
            //        conn->close()
            //    }
            //}

            return -1;
    }

    return 0;
}

#endif
