//
//  WSService.cpp
//  xptools
//
//  Created by Gaetan de Villele on 20/03/2022.
//

#include "WSService.hpp"

// C++
#include <algorithm>
#include <cassert>

#if defined(__VX_SINGLE_THREAD) || !defined(__VX_USE_LIBWEBSOCKETS)
#define LOCK_GUARD_CONTEXT
#define LOCK_GUARD_INTERRUPTED
#else
#include <thread>
#define LOCK_GUARD_CONTEXT std::lock_guard<std::mutex> lock(_contextMutex);
#define LOCK_GUARD_INTERRUPTED std::lock_guard<std::mutex> lock(_serviceThreadInterruptedMutex);
#endif

// xptools
#include "vxlog.h"
#include "HttpRequest.hpp"

#define BODY_BUF_SIZE 2048
#define WS_WRITE_BUF_SIZE 512 // arbitrary size

// #define WSSERVICE_DEBUG_LOG(...) vxlog_debug(__VA_ARGS__)
#define WSSERVICE_DEBUG_LOG(...)

// OpenSSL uses the system trust store.  mbedTLS / WolfSSL have to be told which
// CA to trust explicitly.
//static const char * const particubes_wildcard_ca_cert =
//    "-----BEGIN CERTIFICATE-----\nMIIF6TCCA9GgAwIBAgIQBeTcO5Q4qzuFl8umoZhQ4zANBgkqhkiG9w0BAQwFADCB\niDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0pl\ncnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNV\nBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTQw\nOTEyMDAwMDAwWhcNMjQwOTExMjM1OTU5WjBfMQswCQYDVQQGEwJGUjEOMAwGA1UE\nCBMFUGFyaXMxDjAMBgNVBAcTBVBhcmlzMQ4wDAYDVQQKEwVHYW5kaTEgMB4GA1UE\nAxMXR2FuZGkgU3RhbmRhcmQgU1NMIENBIDIwggEiMA0GCSqGSIb3DQEBAQUAA4IB\nDwAwggEKAoIBAQCUBC2meZV0/9UAPPWu2JSxKXzAjwsLibmCg5duNyj1ohrP0pIL\nm6jTh5RzhBCf3DXLwi2SrCG5yzv8QMHBgyHwv/j2nPqcghDA0I5O5Q1MsJFckLSk\nQFEW2uSEEi0FXKEfFxkkUap66uEHG4aNAXLy59SDIzme4OFMH2sio7QQZrDtgpbX\nbmq08j+1QvzdirWrui0dOnWbMdw+naxb00ENbLAb9Tr1eeohovj0M1JLJC0epJmx\nbUi8uBL+cnB89/sCdfSN3tbawKAyGlLfOGsuRTg/PwSWAP2h9KK71RfWJ3wbWFmV\nXooS/ZyrgT5SKEhRhWvzkbKGPym1bgNi7tYFAgMBAAGjggF1MIIBcTAfBgNVHSME\nGDAWgBRTeb9aqitKz1SA4dibwJ3ysgNmyzAdBgNVHQ4EFgQUs5Cn2MmvTs1hPJ98\nrV1/Qf1pMOowDgYDVR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYD\nVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMCIGA1UdIAQbMBkwDQYLKwYBBAGy\nMQECAhowCAYGZ4EMAQIBMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNl\ncnRydXN0LmNvbS9VU0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNy\nbDB2BggrBgEFBQcBAQRqMGgwPwYIKwYBBQUHMAKGM2h0dHA6Ly9jcnQudXNlcnRy\ndXN0LmNvbS9VU0VSVHJ1c3RSU0FBZGRUcnVzdENBLmNydDAlBggrBgEFBQcwAYYZ\naHR0cDovL29jc3AudXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEAWGf9\ncrJq13xhlhl+2UNG0SZ9yFP6ZrBrLafTqlb3OojQO3LJUP33WbKqaPWMcwO7lWUX\nzi8c3ZgTopHJ7qFAbjyY1lzzsiI8Le4bpOHeICQW8owRc5E69vrOJAKHypPstLbI\nFhfFcvwnQPYT/pOmnVHvPCvYd1ebjGU6NSU2t7WKY28HJ5OxYI2A25bUeo8tqxyI\nyW5+1mUfr13KFj8oRtygNeX56eXVlogMT8a3d2dIhCe2H7Bo26y/d7CQuKLJHDJd\nArolQ4FCR7vY4Y8MDEZf7kYzawMUgtN+zY+vkNaOJH1AQrRqahfGlZfh8jjNp+20\nJ0CT33KpuMZmYzc4ZCIwojvxuch7yPspOqsactIGEk72gtQjbz7Dk+XYtsDe3CMW\n1hMwt6CaDixVBgBwAc/qOR2A24j3pSC4W/0xJmmPLQphgzpHphNULB7j7UTKvGof\nKA5R2d4On3XNDgOVyvnFqSot/kGkoUeuDcL5OWYzSlvhhChZbH2UF3bkRYKtcCD9\n0m9jqNf6oDP6N8v3smWe2lBvP+Sn845dWDKXcCMu5/3EFZucJ48y7RetWIExKREa\nm9T8bJUox04FB6b9HbwZ4ui3uRGKLXASUoWNjDNKD/yZkuBjcNqllEdjB+dYxzFf\nBT02Vf6Dsuimrdfp5gJ0iHRc2jTbkNJtUQoj1iM=\n-----END CERTIFICATE-----\n";

using namespace vx;

#if defined(__VX_USE_LIBWEBSOCKETS)
// used in the callback for uncommon headers
typedef struct {
    lws *wsi;
    std::unordered_map<std::string, std::string> *headers;
} headersAndWsi;
#endif

// --------------------------------------------------
//
// MARK: - Functions' prototypes -
//
// --------------------------------------------------

#if defined(__VX_USE_LIBWEBSOCKETS)

int lws_callback_http(struct lws *wsi,
                      enum lws_callback_reasons reason,
                      void *user,
                      void *in,
                      size_t len);

int lws_callback_ws_join(struct lws *wsi,
                         enum lws_callback_reasons reason,
                         void *user,
                         void *in,
                         size_t len);

#endif

// --------------------------------------------------
//
// MARK: - Public -
//
// --------------------------------------------------

WSService *WSService::_sharedInstance = nullptr;

WSService *WSService::shared() {
    if (WSService::_sharedInstance == nullptr) {
        WSService::_sharedInstance = new WSService();
        WSService::_sharedInstance->_init();
#if defined(__VX_USE_LIBWEBSOCKETS)
        const int logs = 0; // LLL_ERR | LLL_WARN | LLL_NOTICE | LLL_INFO | LLL_DEBUG | LLL_EXT
        lws_set_log_level(logs, nullptr);
#endif
    }
    return WSService::_sharedInstance;
}

WSService::~WSService() {
#if !defined(__VX_SINGLE_THREAD) && defined(__VX_USE_LIBWEBSOCKETS)
    // stop service thread
    if (_serviceThread.joinable()) {
        {
            LOCK_GUARD_INTERRUPTED
            assert(_serviceThreadInterrupted == false);
            _serviceThreadInterrupted = true;
        }
        // wait for thread function to return
        _serviceThread.join();
    } else {
        vxlog_error("[~WSService] this should not happen");
    }
#endif

    // TODO: make sure _lws_context is freed

    // free lws protocols
    if (_lws_protocols != nullptr) {
        for (int i = 0; i < P3S_LWS_PROTOCOL_COUNT; i++) {
            free(_lws_protocols[i]);
        }
        free(_lws_protocols);
    }

#if defined(__VX_PLATFORM_WASM)
    emscripten_websocket_deinitialize();
#endif
}

void WSService::sendHttpRequest(HttpRequest_SharedPtr httpReq) {
    if (httpReq == nullptr) { return; }
#if defined(__VX_USE_LIBWEBSOCKETS)
    _httpRequestWaitingQueue.push(httpReq);
    {
        LOCK_GUARD_CONTEXT
        if (_contextReady) {
            lws_cancel_service(_lws_context);
        }
    }
#endif
}

void WSService::cancelHttpRequest(HttpRequest_SharedPtr httpReq) {
    if (httpReq == nullptr) { return; }
#if defined(__VX_USE_LIBWEBSOCKETS)
    {
        LOCK_GUARD_CONTEXT
        if (_contextReady) {
            lws_cancel_service(_lws_context);
        }
    }
#endif
}

void WSService::requestWSConnection(WSConnection_SharedPtr wsConn) {
    if (wsConn == nullptr) { return; }
#if defined(__VX_USE_LIBWEBSOCKETS)
    _wsConnectionWaitingQueue.push(wsConn);
    {
        LOCK_GUARD_CONTEXT
        if (_contextReady) {
            lws_cancel_service(_lws_context);
        }
    }
#else // EMSCRIPTEN
    _wsConnections.emplace(wsConn);
#endif
}

// Notifies LWS that this connection has some data available to send.
void WSService::scheduleWSConnectionWrite(WSConnection_SharedPtr wsConn) {
    if (wsConn == nullptr) {
        return;
    }

#if defined(__VX_USE_LIBWEBSOCKETS)

    // if this connection is already writing, we don't need to trigger the
    // lws "writable" callback.
    if (wsConn->isWriting() == true) {
        return;
    }

    //
    lws *wsi = wsConn->getWsi();
    if (wsi == nullptr) {
        vxlog_error("[WSService::scheduleWSConnectionWrite] connection is NULL");
        return;
    }
    LOCK_GUARD_CONTEXT
    if (_contextReady) {
        // this will trigger a call of the callback function, with the reason
        // LWS_CALLBACK_EVENT_WAIT_CANCELLED. There, we'll be able to check
        // whether a write is pending, and call lws_callback_on_writable().
        lws_cancel_service_pt(wsi);
    }
#endif

#if defined(__VX_PLATFORM_WASM)
#define WASM_WEBSOCKET_WRITE_BUFFER_SIZE 512
    static char* buffer[WASM_WEBSOCKET_WRITE_BUFFER_SIZE];
    WSBackend wsi = wsConn->getWsi();
    bool isFirstFragment = true;
    bool partial = true;
    size_t n = 0;
    do {
        n = wsConn->write(reinterpret_cast<char*>(buffer), WASM_WEBSOCKET_WRITE_BUFFER_SIZE, isFirstFragment, partial);
        if (n > 0) {
            EMSCRIPTEN_RESULT r = emscripten_websocket_send_binary(wsi, buffer, n);
        }
    } while (n > 0);

#endif
}

#if defined(__VX_USE_LIBWEBSOCKETS)
std::vector<WSConnection_WeakPtr>& WSService::getWSConnectionsActive() {
    return _wsConnectionsActive;
}

const std::vector<lws_token_indexes>& WSService::getHeadersToParse() {
    return _headersToParse;
}
#endif

// --------------------------------------------------
//
// MARK: - Private -
//
// --------------------------------------------------

WSService::WSService() :
#if defined(__VX_USE_LIBWEBSOCKETS)
_httpRequestWaitingQueue(),
_wsConnectionWaitingQueue(),
_wsConnectionsActive(),
#else
_wsConnections(),
#endif
#if !defined(__VX_SINGLE_THREAD) && defined(__VX_USE_LIBWEBSOCKETS)
_serviceThread(),
_contextMutex(),
_serviceThreadInterruptedMutex(),
#endif
_serviceThreadInterrupted(false),
_lws_protocols(nullptr),
_lws_context(nullptr),
_contextReady(false) {
#if defined(__VX_USE_LIBWEBSOCKETS)
    _headersToParse.push_back(WSI_TOKEN_GET_URI);
    _headersToParse.push_back(WSI_TOKEN_POST_URI);
    _headersToParse.push_back(WSI_TOKEN_OPTIONS_URI);
    _headersToParse.push_back(WSI_TOKEN_HOST);
    _headersToParse.push_back(WSI_TOKEN_CONNECTION);
    _headersToParse.push_back(WSI_TOKEN_UPGRADE);
    _headersToParse.push_back(WSI_TOKEN_ORIGIN);
    _headersToParse.push_back(WSI_TOKEN_DRAFT);
    _headersToParse.push_back(WSI_TOKEN_CHALLENGE);
    _headersToParse.push_back(WSI_TOKEN_EXTENSIONS);
    _headersToParse.push_back(WSI_TOKEN_KEY1);
    _headersToParse.push_back(WSI_TOKEN_KEY2);
    _headersToParse.push_back(WSI_TOKEN_PROTOCOL);
    _headersToParse.push_back(WSI_TOKEN_ACCEPT);
    _headersToParse.push_back(WSI_TOKEN_NONCE);
    _headersToParse.push_back(WSI_TOKEN_HTTP);
    _headersToParse.push_back(WSI_TOKEN_HTTP2_SETTINGS);
    _headersToParse.push_back(WSI_TOKEN_HTTP_ACCEPT);
    _headersToParse.push_back(WSI_TOKEN_HTTP_AC_REQUEST_HEADERS);
    _headersToParse.push_back(WSI_TOKEN_HTTP_IF_MODIFIED_SINCE);
    _headersToParse.push_back(WSI_TOKEN_HTTP_IF_NONE_MATCH);
    _headersToParse.push_back(WSI_TOKEN_HTTP_ACCEPT_ENCODING);
    _headersToParse.push_back(WSI_TOKEN_HTTP_ACCEPT_LANGUAGE);
    _headersToParse.push_back(WSI_TOKEN_HTTP_PRAGMA);
    _headersToParse.push_back(WSI_TOKEN_HTTP_CACHE_CONTROL);
    _headersToParse.push_back(WSI_TOKEN_HTTP_AUTHORIZATION);
    _headersToParse.push_back(WSI_TOKEN_HTTP_COOKIE);
    _headersToParse.push_back(WSI_TOKEN_HTTP_CONTENT_LENGTH);
    _headersToParse.push_back(WSI_TOKEN_HTTP_CONTENT_TYPE);
    _headersToParse.push_back(WSI_TOKEN_HTTP_DATE);
    _headersToParse.push_back(WSI_TOKEN_HTTP_RANGE);
    _headersToParse.push_back(WSI_TOKEN_HTTP_REFERER);
    _headersToParse.push_back(WSI_TOKEN_KEY);
    _headersToParse.push_back(WSI_TOKEN_VERSION);
    _headersToParse.push_back(WSI_TOKEN_SWORIGIN);
    _headersToParse.push_back(WSI_TOKEN_HTTP_COLON_AUTHORITY);
    _headersToParse.push_back(WSI_TOKEN_HTTP_COLON_METHOD);
    _headersToParse.push_back(WSI_TOKEN_HTTP_COLON_PATH);
    _headersToParse.push_back(WSI_TOKEN_HTTP_COLON_SCHEME);
    _headersToParse.push_back(WSI_TOKEN_HTTP_COLON_STATUS);
    _headersToParse.push_back(WSI_TOKEN_HTTP_ACCEPT_CHARSET);
    _headersToParse.push_back(WSI_TOKEN_HTTP_ACCEPT_RANGES);
    _headersToParse.push_back(WSI_TOKEN_HTTP_ACCESS_CONTROL_ALLOW_ORIGIN);
    _headersToParse.push_back(WSI_TOKEN_HTTP_AGE);
    _headersToParse.push_back(WSI_TOKEN_HTTP_ALLOW);
    _headersToParse.push_back(WSI_TOKEN_HTTP_CONTENT_DISPOSITION);
    _headersToParse.push_back(WSI_TOKEN_HTTP_CONTENT_ENCODING);
    _headersToParse.push_back(WSI_TOKEN_HTTP_CONTENT_LANGUAGE);
    _headersToParse.push_back(WSI_TOKEN_HTTP_CONTENT_LOCATION);
    _headersToParse.push_back(WSI_TOKEN_HTTP_CONTENT_RANGE);
    _headersToParse.push_back(WSI_TOKEN_HTTP_ETAG);
    _headersToParse.push_back(WSI_TOKEN_HTTP_EXPECT);
    _headersToParse.push_back(WSI_TOKEN_HTTP_EXPIRES);
    _headersToParse.push_back(WSI_TOKEN_HTTP_FROM);
    _headersToParse.push_back(WSI_TOKEN_HTTP_IF_MATCH);
    _headersToParse.push_back(WSI_TOKEN_HTTP_IF_RANGE);
    _headersToParse.push_back(WSI_TOKEN_HTTP_IF_UNMODIFIED_SINCE);
    _headersToParse.push_back(WSI_TOKEN_HTTP_LAST_MODIFIED);
    _headersToParse.push_back(WSI_TOKEN_HTTP_LINK);
    _headersToParse.push_back(WSI_TOKEN_HTTP_LOCATION);
    _headersToParse.push_back(WSI_TOKEN_HTTP_MAX_FORWARDS);
    _headersToParse.push_back(WSI_TOKEN_HTTP_PROXY_AUTHENTICATE);
    _headersToParse.push_back(WSI_TOKEN_HTTP_PROXY_AUTHORIZATION);
    _headersToParse.push_back(WSI_TOKEN_HTTP_REFRESH);
    _headersToParse.push_back(WSI_TOKEN_HTTP_RETRY_AFTER);
    _headersToParse.push_back(WSI_TOKEN_HTTP_SERVER);
    _headersToParse.push_back(WSI_TOKEN_HTTP_SET_COOKIE);
    _headersToParse.push_back(WSI_TOKEN_HTTP_STRICT_TRANSPORT_SECURITY);
    _headersToParse.push_back(WSI_TOKEN_HTTP_TRANSFER_ENCODING);
    _headersToParse.push_back(WSI_TOKEN_HTTP_USER_AGENT);
    _headersToParse.push_back(WSI_TOKEN_HTTP_VARY);
    _headersToParse.push_back(WSI_TOKEN_HTTP_VIA);
    _headersToParse.push_back(WSI_TOKEN_HTTP_WWW_AUTHENTICATE);
    _headersToParse.push_back(WSI_TOKEN_PATCH_URI);
    _headersToParse.push_back(WSI_TOKEN_PUT_URI);
    _headersToParse.push_back(WSI_TOKEN_DELETE_URI);
    _headersToParse.push_back(WSI_TOKEN_HTTP_URI_ARGS);
    _headersToParse.push_back(WSI_TOKEN_PROXY);
    _headersToParse.push_back(WSI_TOKEN_HTTP_X_REAL_IP);
    _headersToParse.push_back(WSI_TOKEN_HTTP1_0);
    _headersToParse.push_back(WSI_TOKEN_X_FORWARDED_FOR);
    _headersToParse.push_back(WSI_TOKEN_CONNECT);
    _headersToParse.push_back(WSI_TOKEN_HEAD_URI);
    _headersToParse.push_back(WSI_TOKEN_TE);
    _headersToParse.push_back(WSI_TOKEN_REPLAY_NONCE);
    _headersToParse.push_back(WSI_TOKEN_COLON_PROTOCOL);
    _headersToParse.push_back(WSI_TOKEN_X_AUTH_TOKEN);
    _headersToParse.push_back(WSI_TOKEN_DSS_SIGNATURE);
#endif
}

void WSService::_init() {
#if defined(__VX_USE_LIBWEBSOCKETS)
#if defined(__VX_SINGLE_THREAD)
    _serviceThreadFunction();
#else
    _serviceThread = std::thread(&WSService::_serviceThreadFunction, this);
#endif
#endif
}

#if defined(__VX_USE_LIBWEBSOCKETS)
void WSService::_serviceThreadFunction() {
    // construct protocols array
    {
        assert(_lws_protocols == nullptr);

        const int protoCount = P3S_LWS_PROTOCOL_COUNT;
        _lws_protocols = reinterpret_cast<struct lws_protocols**>(malloc(sizeof(struct lws_protocols*) * (protoCount + 1)));
        if (_lws_protocols == nullptr) {
            vxlog_error("[WSService] failed to create protocols struct");
            return;
        }

        _lws_protocols[0] = reinterpret_cast<struct lws_protocols*>(malloc(sizeof(struct lws_protocols)));
        if (_lws_protocols[0] == nullptr) {
            vxlog_error("[WSService] failed to create protocols[0] struct");
            // TODO: free allocated memory
            return;
        }
        _lws_protocols[0]->name = P3S_LWS_PROTOCOL_HTTP;
        _lws_protocols[0]->callback = lws_callback_http;
        _lws_protocols[0]->per_session_data_size = 0;
        _lws_protocols[0]->rx_buffer_size = 0;
        _lws_protocols[0]->id = 0;
        _lws_protocols[0]->user = nullptr; // userdata pointer
        _lws_protocols[0]->tx_packet_size = 0;

        _lws_protocols[1] = reinterpret_cast<struct lws_protocols*>(malloc(sizeof(struct lws_protocols)));
        if (_lws_protocols[1] == nullptr) {
            vxlog_error("[WSService] failed to create protocols[1] struct");
            // TODO: free allocated memory
            return;
        }
        _lws_protocols[1]->name = P3S_LWS_PROTOCOL_WS_JOIN;
        _lws_protocols[1]->callback = lws_callback_ws_join;
        _lws_protocols[1]->per_session_data_size = 0;
        _lws_protocols[1]->rx_buffer_size = 0;
        _lws_protocols[1]->id = 0;
        _lws_protocols[1]->user = nullptr; // userdata pointer
        _lws_protocols[1]->tx_packet_size = 0;

        _lws_protocols[protoCount] = nullptr; // marks the end of array
    }

    // construct pvo

    struct lws_protocol_vhost_options _lws_pvo_interrupted;
    struct lws_protocol_vhost_options _lws_pvo;
//    // pvo
//    _lws_pvo_wsserver = {
//        nullptr,
//        nullptr,
//        "wsserver", // pvo name
//        reinterpret_cast<const char *>(this) // pvo value
//    };
//
//    _lws_pvo_options = {
//        &_lws_pvo_wsserver,
//        nullptr,
//        "options", // pvo name
//        reinterpret_cast<const char *>(&_lws_options) // pvo value
//    };

    _lws_pvo_interrupted = {
        nullptr,
        nullptr,
        "WSServicePtr", // pvo name
        reinterpret_cast<const char *>(this) // pvo value
    };

    _lws_pvo = {
        nullptr,                  // "next" pvo linked-list
        &_lws_pvo_interrupted,    // "child" pvo linked-list
        P3S_LWS_PROTOCOL_WS_JOIN, // protocol name we belong to on this vhost
        ""                        // ignored
    };

    // construct lws_context

    // Create context
    lws_context_creation_info ctxInfo;
    memset(&ctxInfo, 0, sizeof(ctxInfo)); // otherwise uninitialized garbage
    ctxInfo.options = (LWS_SERVER_OPTION_DO_SSL_GLOBAL_INIT |
                       LWS_SERVER_OPTION_CREATE_VHOST_SSL_CTX);
    ctxInfo.port = CONTEXT_PORT_NO_LISTEN; // a client doesn't listen on a port
    ctxInfo.pprotocols = const_cast<const struct lws_protocols**>(_lws_protocols);
    // ctxInfo.register_notifier_list = na;
    ctxInfo.connect_timeout_secs = 60;
    ctxInfo.timeout_secs = 60;
    ctxInfo.client_ssl_cipher_list = nullptr;
    ctxInfo.client_ssl_ca_mem = nullptr;
    ctxInfo.client_ssl_ca_mem_len = 0;
    ctxInfo.pvo = &_lws_pvo;

    // ctxInfo.client_ssl_ca_mem = particubes_wildcard_ca_cert;
    // ctxInfo.client_ssl_ca_mem_len = static_cast<unsigned int>(strlen(particubes_wildcard_ca_cert));

    // TCP keep-alive
    // ctxInfo.ka_time = 500; // 500sec
    // ctxInfo.ka_probes = 20; // nb of retries
    // ctxInfo.ka_interval = 5; // interval between retries
    // SSL certs
    // ctxInfo.ssl_ca_filepath = "/Users/gaetan/Desktop/ca_cert.pem";
    // ctxInfo.ssl_cert_filepath = nullptr;
    // ctxInfo.ssl_private_key_filepath = nullptr;

    _lws_context = lws_create_context(&ctxInfo);
    if (_lws_context == nullptr) {
        vxlog_error("[WSService] failed to create LWS context");
    }

    {
        LOCK_GUARD_CONTEXT
        _contextReady = true;
    }

    bool interrupted = false;
    int n = 0;
    HttpRequest_SharedPtr httpReq = nullptr;
    WSConnection_SharedPtr wsConn = nullptr;
    while (interrupted == false && n >= 0) {

        // check if there is a http request to send
        if (_httpRequestWaitingQueue.pop(httpReq)) {
            // init connection
            lws_client_connect_info connectInfo;
            memset(&connectInfo, 0, sizeof(connectInfo)); // otherwise uninitialized garbage
            // use shared lws_context
            connectInfo.context = _lws_context;
            connectInfo.protocol = P3S_LWS_PROTOCOL_HTTP;
            // if method is NULL then a WebSocket upgrade will be attempted,
            // if method is NOT NULL, it will be a regular HTTP(S) request.
            assert(httpReq->getMethod() == "GET" ||
                   httpReq->getMethod() == "POST" ||
                   httpReq->getMethod() == "PATCH" ||
                   httpReq->getMethod() == "DELETE");
            connectInfo.method = httpReq->getMethod().c_str();
            connectInfo.address = httpReq->getHost().c_str();
            connectInfo.host = connectInfo.address;
            connectInfo.path = httpReq->getPathAndQuery().c_str();
            connectInfo.port = httpReq->getPort();
            connectInfo.userdata = new HttpRequest_SharedPtr(httpReq);

            // 0, or a combination of LCCSCF_ flags
            if (httpReq->getSecure()) {
                connectInfo.ssl_connection = (LCCSCF_USE_SSL |
                                              LCCSCF_ALLOW_SELFSIGNED |
                                              LCCSCF_SKIP_SERVER_CERT_HOSTNAME_CHECK);
            } else {
                connectInfo.ssl_connection = 0;
            }

            lws* wsi = lws_client_connect_via_info(&connectInfo);
            if (wsi == nullptr) {
                vxlog_error("HttpRequest failed %s", httpReq->getPath().c_str());
                // continue to pop following http requests
                // they may also fail instantly (if there's no network for example)
                // not using `continue` could mean getting stuck on lws_service call
                // not processing other HttpRequests.
                continue;
            }
            httpReq = nullptr; // release
        }

        // check if there is a WSConnection waiting to connect
        if (_wsConnectionWaitingQueue.pop(wsConn)) {
            // init connection
            lws_client_connect_info connectInfo;
            memset(&connectInfo, 0, sizeof(connectInfo)); // otherwise uninitialized garbage
            connectInfo.context = _lws_context;
            connectInfo.protocol = nullptr; // no sub-protocol
            connectInfo.local_protocol_name = P3S_LWS_PROTOCOL_WS_JOIN;
            // if method is NULL then a WebSocket upgrade will be attempted,
            // if method is NOT NULL, it will be a regular HTTP(S) request.
            connectInfo.method = nullptr;
            connectInfo.address = wsConn->getHost().c_str();
            connectInfo.host = wsConn->getHost().c_str();
            connectInfo.port = wsConn->getPort();
            connectInfo.path = wsConn->getPath().c_str();
            connectInfo.userdata = new WSConnection_SharedPtr(wsConn);
            connectInfo.priority = 6;

            // 0, or a combination of LCCSCF_ flags
            if (wsConn->getSecure()) {
                connectInfo.ssl_connection = (LCCSCF_USE_SSL |
                                              LCCSCF_ALLOW_SELFSIGNED |
                                              LCCSCF_SKIP_SERVER_CERT_HOSTNAME_CHECK);
            } else {
                connectInfo.ssl_connection = 0;
            }

            lws *wsi = lws_client_connect_via_info(&connectInfo);
            if (wsi != nullptr) {
//                // associate wsi to WSConnection
//                WSBackend wsb = new WSBackend(wsi);
//                if (wsb == nullptr) {
//                    vxlog_error("[WSService][WSConnection] failed to alloc WSBackend");
//                }
                wsConn->setWsi(wsi);
            } else {
                vxlog_error("WSConnection failed");
                // continue to pop following connection and/or http request
                // they may also fail instantly (if there's no network for example)
                // not using `continue` could mean getting stuck on lws_service call
                // not processing other HttpRequests and WSConnections.
                continue;
            }

            // insert connection in collection of active connections
            WSConnection_WeakPtr weakConn(wsConn);
            _wsConnectionsActive.push_back(weakConn);

            wsConn = nullptr; // release
        }

        // service the lws context
        // /!\ If it crashes here, please check config.json doesn't contain
        // HTTPS but only HTTP.
        n = lws_service(_lws_context, 0);

        // update value of `interrupted`
        {
            LOCK_GUARD_INTERRUPTED
            interrupted = _serviceThreadInterrupted;
        }
    }

    // if n < 0 it means the lws service returned an error
    // if interrupted == true it means the app stopped the processing

    // TODO: gdevillele: cleanup/destroy lws_context

    // lws_context_destroy(ctx);
    // ctx = nullptr;

    WSSERVICE_DEBUG_LOG("[WSService] thread exited (_serviceThreadFunction)");
}
#endif

// --------------------------------------------------
//
// MARK: - C functions -
//
// --------------------------------------------------

#if defined(__VX_USE_LIBWEBSOCKETS)
int lws_callback_ws_join(struct lws *wsi,
                         enum lws_callback_reasons reason,
                         void *user,
                         void *in,
                         size_t len) {
    // WSSERVICE_DEBUG_LOG("⚡️ [WSConnection] lws callback %d", reason);

    WSConnection_SharedPtr wsConn = nullptr;
    switch (reason) {
        case LWS_CALLBACK_CLIENT_ESTABLISHED:
        case LWS_CALLBACK_CLIENT_WRITEABLE:
        case LWS_CALLBACK_CLIENT_RECEIVE:
        case LWS_CALLBACK_CLIENT_CONNECTION_ERROR:
        case LWS_CALLBACK_CLIENT_CLOSED: {
            if (user != nullptr) {
                wsConn = *(reinterpret_cast<WSConnection_SharedPtr*>(user));
                if (wsConn->isClosed()) { // could have been cancelled
                    delete reinterpret_cast<WSConnection_SharedPtr*>(user);
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
            // WSSERVICE_DEBUG_LOG("⚡️ [WSConnection] LWS_CALLBACK_PROTOCOL_INIT");
            void* buf = lws_protocol_vh_priv_zalloc(lws_get_vhost(wsi),
                                                    lws_get_protocol(wsi),
                                                    sizeof(vx::WSService::ws_vhd));
            if (buf == nullptr) { return -1; } // error
            vx::WSService::ws_vhd* vhd = reinterpret_cast<vx::WSService::ws_vhd*>(buf);
            if (vhd == nullptr) { return -1; }
            vhd->context = lws_get_context(wsi);
            vhd->vhost = lws_get_vhost(wsi);
            // get the pointers we were passed in pvo
            const struct lws_protocol_vhost_options* pvo = reinterpret_cast<const struct lws_protocol_vhost_options *>(in);
            const struct lws_protocol_vhost_options* pvo_wsservice = lws_pvo_search(pvo, "WSServicePtr");
            vhd->wsservice = const_cast<WSService*>(reinterpret_cast<const WSService*>(pvo_wsservice->value));

            break;
        }
        case LWS_CALLBACK_PROTOCOL_DESTROY: {
            // WSSERVICE_DEBUG_LOG("⚡️ [WSConnection] LWS_CALLBACK_PROTOCOL_DESTROY");
            // no need to free the buffer allocated using lws_protocol_vh_priv_zalloc
            // it's done automatically
            break;
        }
        case LWS_CALLBACK_EVENT_WAIT_CANCELLED: { // 71
            void* vhd_ptr = lws_protocol_vh_priv_get(lws_get_vhost(wsi), lws_get_protocol(wsi));
            struct vx::WSService::ws_vhd *vhd = reinterpret_cast<struct vx::WSService::ws_vhd *>(vhd_ptr);
            if (vhd != nullptr) {

                std::vector<WSConnection_WeakPtr>& activeConnections = vhd->wsservice->getWSConnectionsActive();
                std::vector<WSConnection_WeakPtr>::iterator it;

                // remove expired weak pointers
                activeConnections.erase(std::remove_if(activeConnections.begin(), activeConnections.end(), [](WSConnection_WeakPtr ptr){
                    return ptr.expired();
                }), activeConnections.end());

                // loop over active connections and call `lws_callback_on_writable` if necessary
                for (it = activeConnections.begin(); it != activeConnections.end(); it++) {
                    WSConnection_SharedPtr strong = (*it).lock();
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
        case LWS_CALLBACK_OPENSSL_LOAD_EXTRA_CLIENT_VERIFY_CERTS: {
            WSSERVICE_DEBUG_LOG("⚡️ [WSConnection] LWS_CALLBACK_OPENSSL_LOAD_EXTRA_CLIENT_VERIFY_CERTS");
            // SSL_CTX* sslctx = reinterpret_cast<SSL_CTX*>(user);
            break;
        }
        case LWS_CALLBACK_OPENSSL_PERFORM_SERVER_CERT_VERIFICATION: {
            WSSERVICE_DEBUG_LOG("⚡️ [WSConnection] LWS_CALLBACK_OPENSSL_PERFORM_SERVER_CERT_VERIFICATION");
            X509_STORE_CTX_set_error(reinterpret_cast<X509_STORE_CTX*>(user), X509_V_OK);
            break;
        }
        case LWS_CALLBACK_OPENSSL_LOAD_EXTRA_SERVER_VERIFY_CERTS: {
            WSSERVICE_DEBUG_LOG("⚡️ [WSConnection] LWS_CALLBACK_OPENSSL_LOAD_EXTRA_SERVER_VERIFY_CERTS");
            // SSL_CTX* sslctx = reinterpret_cast<SSL_CTX*>(user);
            break;
        }
        case LWS_CALLBACK_CLIENT_ESTABLISHED: {
            WSSERVICE_DEBUG_LOG("⚡️ [WSConnection] LWS_CALLBACK_CLIENT_ESTABLISHED");

            // call delegate function
            if (wsConn != nullptr) {
                wsConn->established();
                std::shared_ptr<ConnectionDelegate> delegate = wsConn->getDelegate().lock();
                if (delegate != nullptr) {
                    delegate->connectionDidEstablish(*(wsConn.get()));
                }
            } else {
                vxlog_error("⚡️ [WSConnection][LWS_CALLBACK_CLIENT_ESTABLISHED] this is not supposed to happen");
            }

            {
                lws_callback_on_writable(wsi);
            }

            break;
        }
        case LWS_CALLBACK_CLIENT_WRITEABLE: {
            WSSERVICE_DEBUG_LOG("⚡️ [WSConnection] LWS_CALLBACK_CLIENT_WRITEABLE");
            // pop bytes that are waiting to be written
            if (wsConn != nullptr) {
                if (wsConn->doneWriting() == false) {

                    static char buf[LWS_PRE + WS_WRITE_BUF_SIZE];
                    char *start = &(buf[LWS_PRE]); // buf + LWS_PRE

                    bool firstFragment;
                    bool partial;
                    const size_t len_to_write = wsConn->write(start, WS_WRITE_BUF_SIZE, firstFragment, partial);

                    int writeMode = 0;
                    // WSSERVICE_DEBUG_LOG("WS write: -----");
                    if (firstFragment) {
                        // first write for this payload
                        if (partial == false) {
                            WSSERVICE_DEBUG_LOG("WS write: single frame, no fragmentation");
                            writeMode = LWS_WRITE_BINARY; // single frame, no fragmentation
                        } else {
                            WSSERVICE_DEBUG_LOG("WS write: first fragment");
                            writeMode = LWS_WRITE_BINARY | LWS_WRITE_NO_FIN; // first fragment
                        }
                    } else {
                        if (partial == true) {
                            WSSERVICE_DEBUG_LOG("WS write: middle fragment");
                            writeMode = LWS_WRITE_CONTINUATION | LWS_WRITE_NO_FIN; // all middle fragments
                        } else {
                            WSSERVICE_DEBUG_LOG("WS write: last fragment");
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

                    if (wsConn->doneWriting() == false) {
                        lws_callback_on_writable(wsi); // request additional write
                        assert(wsConn->isWriting() == true);
                    } else {
                        wsConn->setIsWriting(false);
                    }
                } else {
                    return 0; // nothing to write
                }
            } else {
                vxlog_error("⚡️ [WSConnection][LWS_CALLBACK_CLIENT_WRITEABLE] this is not supposed to happen");
            }
            break;
        }
        case LWS_CALLBACK_CLIENT_RECEIVE: {
            const bool isFinalFragment = lws_is_final_fragment(wsi) != 0;
            const bool isBinary = lws_frame_is_binary(wsi) != 0;

            WSSERVICE_DEBUG_LOG("⚡️ [WSConnection] LWS_CALLBACK_CLIENT_RECEIVE: %4d (rpp %5d, first %d, last %d, bin %d)",
                                static_cast<int>(len),
                                static_cast<int>(lws_remaining_packet_payload(wsi)),
                                lws_is_first_fragment(wsi) != 0,
                                isFinalFragment,
                                isBinary);

            assert(isBinary);

            if (wsConn != nullptr) {
                // notify the connection of the received bytes
                // (this can trigger a delegate function)
                wsConn->receivedBytes(reinterpret_cast<char*>(in), len, isFinalFragment);
            } else {
                vxlog_error("⚡️ [WSConnection][LWS_CALLBACK_CLIENT_RECEIVE] this is not supposed to happen");
            }

            break;
        }
        case LWS_CALLBACK_CLIENT_CONNECTION_ERROR: {
            WSSERVICE_DEBUG_LOG("⚡️ [WSConnection] LWS_CALLBACK_CLIENT_CONNECTION_ERROR");
            if (wsConn != nullptr) {
                wsConn->closeOnError();
                delete reinterpret_cast<WSConnection_SharedPtr*>(user); // delete the WSConnection
                lws_set_wsi_user(wsi, nullptr);
                return -1; // destroy this wsi
            } else {
                vxlog_error("⚡️ [WSConnection][LWS_CALLBACK_CLIENT_CONNECTION_ERROR] this is not supposed to happen");
            }

            break;
        }
        case LWS_CALLBACK_CLIENT_CLOSED: {
            WSSERVICE_DEBUG_LOG("⚡️ [WSConnection] LWS_CALLBACK_CLIENT_CLOSED");
            // notify WSConnection of the disconnection
            if (wsConn != nullptr) {
                wsConn->closeOnError(); // connection comes from server side, consider it to be an error
                delete reinterpret_cast<WSConnection_SharedPtr*>(user); // delete the WSConnection
                lws_set_wsi_user(wsi, nullptr);
                return -1; // destroy this wsi
            }
            break;
        }
        case LWS_CALLBACK_CLIENT_APPEND_HANDSHAKE_HEADER: {
            // you only need this if you need to do Basic Auth
            WSSERVICE_DEBUG_LOG("⚡️ [WSConnection] LWS_CALLBACK_CLIENT_APPEND_HANDSHAKE_HEADER");
            break;
        }

        case LWS_CALLBACK_CLIENT_FILTER_PRE_ESTABLISH: // 2
        case LWS_CALLBACK_CLIENT_RECEIVE_PONG: // 9
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
        case LWS_CALLBACK_VHOST_CERT_AGING: // 72
        case LWS_CALLBACK_CLIENT_HTTP_BIND_PROTOCOL: // 85
        case LWS_CALLBACK_HTTP_CONFIRM_UPGRADE: // 86
        case LWS_CALLBACK_CLIENT_HTTP_DROP_PROTOCOL: // 76
        case LWS_CALLBACK_WS_SERVER_DROP_PROTOCOL: // 78
        case LWS_CALLBACK_WS_CLIENT_DROP_PROTOCOL: // 80
        case LWS_CALLBACK_CONNECTING: // 105
            // WSSERVICE_DEBUG_LOG("lws_callback_ws_join case: %d", reason);
            // Nothing to do but keeping empty cases on purpose
            break;

        default:
            vxlog_error("lws_callback_ws_join case not handled: %d", reason);
            // TODO: cleanup?
            return -1;
    }

    return 0;
}

// opaque is a std::unordered_map<std::string, std::string> containing headers
void headerCustomForEach(const char *name, int nlen, void *opaque) {
    if (opaque == nullptr) {
        return;
    }
    headersAndWsi * const headerWSI = static_cast<headersAndWsi*>(opaque);

    // get lenght of the header value
    const int valueLength = lws_hdr_custom_length(headerWSI->wsi, name, nlen);
    char *valueBuf = static_cast<char *>(malloc(valueLength + 1));
    if (valueBuf == nullptr) {
        return;
    }
    lws_hdr_custom_copy(headerWSI->wsi, valueBuf, valueLength + 1, name, nlen);
    valueBuf[valueLength] = 0;

    std::string key(name, nlen);
    // lowercase the key
    for (size_t i = 0; i < key.length(); i += 1) {
        key.replace(i, 1, 1, std::tolower(key.at(i)));
    }

    const std::string value(valueBuf, valueLength);
    free(valueBuf);
    valueBuf = nullptr;

    // remove every colon in the key
    key.erase(std::remove(key.begin(), key.end(), ':'), key.end());

    headerWSI->headers->emplace(key, value);
}

int lws_callback_http(struct lws *wsi,
                      enum lws_callback_reasons reason,
                      void *user,
                      void *in,
                      size_t len) {
    // WSSERVICE_DEBUG_LOG("🌎 callback_http %d", reason);

    HttpRequest_SharedPtr req = nullptr;
    switch (reason) {
        case LWS_CALLBACK_CLIENT_FILTER_PRE_ESTABLISH:
        case LWS_CALLBACK_ESTABLISHED_CLIENT_HTTP:
        case LWS_CALLBACK_CLIENT_APPEND_HANDSHAKE_HEADER:
        case LWS_CALLBACK_RECEIVE_CLIENT_HTTP_READ:
        case LWS_CALLBACK_CLIENT_HTTP_WRITEABLE:
        case LWS_CALLBACK_COMPLETED_CLIENT_HTTP:
        case LWS_CALLBACK_CLOSED_CLIENT_HTTP:
        case LWS_CALLBACK_CLIENT_CONNECTION_ERROR: {
            if (user != nullptr) {
                req = *(reinterpret_cast<HttpRequest_SharedPtr*>(user));
                if (req->getStatus() == HttpRequest::Status::CANCELLED) {
                    delete reinterpret_cast<HttpRequest_SharedPtr*>(user);
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

        case LWS_CALLBACK_OPENSSL_LOAD_EXTRA_CLIENT_VERIFY_CERTS: {
            // SSL_CTX* sslctx = reinterpret_cast<SSL_CTX*>(user);
            break;
        }

        case LWS_CALLBACK_OPENSSL_PERFORM_SERVER_CERT_VERIFICATION: {
            X509_STORE_CTX_set_error(reinterpret_cast<X509_STORE_CTX*>(user), X509_V_OK);
            break;
        }

        case LWS_CALLBACK_OPENSSL_LOAD_EXTRA_SERVER_VERIFY_CERTS: {
            // SSL_CTX* sslctx = reinterpret_cast<SSL_CTX*>(user);
            break;
        }

        case LWS_CALLBACK_CLIENT_CONNECTION_ERROR: {
            WSSERVICE_DEBUG_LOG("🌎 callback : LWS_CALLBACK_CLIENT_CONNECTION_ERROR");
            // failure without even managing to connect to the server
            if (req != nullptr) {
                req->getResponse().setSuccess(false);
                req->callCallback();
            }
            break;
        }

        case LWS_CALLBACK_ESTABLISHED_CLIENT_HTTP: {
            // get server IP address
            // char buf[128]; lws_get_peer_simple(wsi, buf, sizeof(buf));

            // get HTTP response status code
            const uint16_t httpStatus = lws_http_client_http_response(wsi); // status should be global
            // store HTTP status code in HttpResponse
            req->getResponse().setStatusCode(httpStatus);

            break;
        }

        case LWS_CALLBACK_CLIENT_APPEND_HANDSHAKE_HEADER: { // you only need this if you need to do Basic Auth

            unsigned char **p = static_cast<unsigned char **>(in);
            unsigned char *end = (*p) + len;

            // write custom headers
            std::string key;
            for (const auto& kv : req->getHeaders()) {
                key = kv.first + ":";
                const int err = lws_add_http_header_by_name(wsi,
                                                            reinterpret_cast<const unsigned char*>(key.c_str()),
                                                            reinterpret_cast<const unsigned char*>(kv.second.c_str()),
                                                            static_cast<int>(kv.second.length()),
                                                            p,
                                                            end);
                if (err != 0) { // error
                    vxlog_error("HTTP : failed to write custom header");
                    break;
                }
            }

            if (req->getMethod() == "GET") {

                // nothing for now

            } else if (req->getMethod() == "POST" || req->getMethod() == "PATCH") {

                const int err = lws_add_http_header_content_length(wsi, req->getBodyBytes().size(), p, end);
                if (err != 0) {
                    // error
                    vxlog_error("HTTP : failed to write header");
                }

                // Tell lws we are going to send the body next...
                if (lws_http_is_redirected_to_get(wsi) == false) {
                    lws_client_http_body_pending(wsi, 1);
                    lws_callback_on_writable(wsi);
                } else {
                    // request has been redirected to GET method.
                    // TODO: do something about it.
                }
            }
            break;
        }

        case LWS_CALLBACK_RECEIVE_CLIENT_HTTP_READ: { // chunks of chunked content, with header removed
            WSSERVICE_DEBUG_LOG("🌎 callback : LWS_CALLBACK_RECEIVE_CLIENT_HTTP_READ");

            // retrieve response bytes and append them in the HttpResponse
            const ::std::string bytes = ::std::string(static_cast<char*>(in), static_cast<int>(len));
            req->getResponse().appendBytes(bytes);

            return 0; // don't passthru
        }
        case LWS_CALLBACK_RECEIVE_CLIENT_HTTP: { // uninterpreted http content
            // WSSERVICE_DEBUG_LOG("🌎 callback : LWS_CALLBACK_RECEIVE_CLIENT_HTTP");

            char buffer[1024 + LWS_PRE];
            char *px = buffer + LWS_PRE;
            int lenx = sizeof(buffer) - LWS_PRE;

            int ret = lws_http_client_read(wsi, &px, &lenx); // calls LWS_CALLBACK_RECEIVE_CLIENT_HTTP_READ ?
            if (ret < 0) { // error
                return -1;
            }

            return 0; // don't passthru
        }

        case LWS_CALLBACK_HTTP_BODY: {
            // WSSERVICE_DEBUG_LOG("🌎 callback : LWS_CALLBACK_HTTP_BODY");
            break;
        }
        case LWS_CALLBACK_HTTP_BODY_COMPLETION: {
            // WSSERVICE_DEBUG_LOG("🌎 callback : LWS_CALLBACK_HTTP_BODY_COMPLETION");
            break;
        }
        case LWS_CALLBACK_CLIENT_HTTP_WRITEABLE: {
            // WSSERVICE_DEBUG_LOG("🌎 callback : LWS_CALLBACK_CLIENT_HTTP_WRITEABLE");

            if (lws_http_is_redirected_to_get(wsi)) {
                // success because it reached the server
                // it's just that we don't expect redirects,
                // so considering this to be a Bad Request.
                req->getResponse().setSuccess(true);
                req->getResponse().setStatusCode(400);
                req->callCallback();
                return 1; // close connection
            }

            // Buffer for writing POST request body
            // NOTE (gdevillele) : apparently with LWS_WRITE_HTTP we don't need the LWS_PRE bytes
            static char buf[LWS_PRE + BODY_BUF_SIZE];
            char *start = &(buf[LWS_PRE]); // buf + LWS_PRE

            const size_t totalRequestLen = req->getBodyBytes().size();
            const size_t alreadyWritten = req->getWritten();
            const size_t to_write = totalRequestLen - alreadyWritten;
            const bool partial = to_write > BODY_BUF_SIZE;
            lws_write_protocol wp = partial ? LWS_WRITE_HTTP : LWS_WRITE_HTTP_FINAL;

            // WSSERVICE_DEBUG_LOG("🌎 WRITEABLE %d %d %d (partial: %s)", totalRequestLen, alreadyWritten, to_write, partial ? "true" : "false");

            const int len_to_write = static_cast<int>(partial ? BODY_BUF_SIZE : to_write);
            memcpy(start, req->getBodyBytes().c_str() + alreadyWritten, len_to_write);
            const int bytesJustWritten = lws_write(wsi,
                                                   reinterpret_cast<uint8_t *>(start),
                                                   len_to_write,
                                                   wp);
            if (bytesJustWritten < len_to_write) {
                // Error, connection is dead.
                return 1;
            }

            req->setWritten(alreadyWritten + bytesJustWritten);

            if (partial) {
                lws_callback_on_writable(wsi); // request additional write
            } else {
                lws_client_http_body_pending(wsi, 0); // all has written
            }
            return 0;
        }

        case LWS_CALLBACK_COMPLETED_CLIENT_HTTP:
        case LWS_CALLBACK_CLOSED_CLIENT_HTTP: { // 45
            // WSSERVICE_DEBUG_LOG("🌎 callback : LWS_CALLBACK_COMPLETED_CLIENT_HTTP");
            if (req != nullptr) {
                // call callback function
                req->getResponse().setSuccess(true);
                if (req->callCallback()) {
                    delete reinterpret_cast<HttpRequest_SharedPtr*>(user);
                    lws_set_wsi_user(wsi, nullptr);
                }
            } else {
                // vxlog_error("[LWS_CALLBACK_COMPLETED_CLIENT_HTTP] this should not happen");
            }
            break;
        }

        case LWS_CALLBACK_CLIENT_FILTER_PRE_ESTABLISH: { // 2
            std::unordered_map<std::string, std::string> headers;
            std::string key;
            std::string value;
            int len = 0;
            char* buf = nullptr;
            lws_token_indexes headerIndex;
            const std::vector<lws_token_indexes>& headersToParse = WSService::shared()->getHeadersToParse();
            for (auto it = headersToParse.begin(); it != headersToParse.end(); it++) {
                headerIndex = *it;
                // parse key
                key = std::string(reinterpret_cast<char*>(const_cast<unsigned char*>(lws_token_to_string(headerIndex))));
                if (key.empty()) {
                    continue; // ignore headers with no name
                }

                // parse value
                len = lws_hdr_total_length(wsi, headerIndex);
                if (len <= 0) {
                    continue; // ignore headers with no value
                }

                buf = reinterpret_cast<char*>(malloc(len + 1)); // +1 for the NULL terminator
                if (buf == nullptr) {
                    continue; // failed to alloc buffer
                }
                if (lws_hdr_copy(wsi, buf, len+1, headerIndex) == -1) {
                    free(buf);
                    continue; // failed to copy header value
                }
                value.assign(buf);
                free(buf);
                buf = nullptr;

                // remove every colon in the key
                key.erase(std::remove(key.begin(), key.end(), ':'), key.end());

                headers.emplace(key, value);
                value.clear();
            }

            // parse non-standard HTTP headers
            headersAndWsi hWSI;
            hWSI.wsi = wsi;
            hWSI.headers = &headers;
            lws_hdr_custom_name_foreach(wsi, headerCustomForEach, static_cast<void *>(&hWSI));

            req->getResponse().setHeaders(std::move(headers));

            // lws_hdr_custom_name_foreach(wsi, headerCustomForEach, nullptr);

            break;
        }

        case LWS_CALLBACK_FILTER_NETWORK_CONNECTION: // 17
        case LWS_CALLBACK_SERVER_NEW_CLIENT_INSTANTIATED: // 19
        case LWS_CALLBACK_FILTER_PROTOCOL_CONNECTION: // 20
        case LWS_CALLBACK_PROTOCOL_INIT: // 27
        case LWS_CALLBACK_WSI_CREATE: // 29
        case LWS_CALLBACK_WSI_DESTROY: // 30
        case LWS_CALLBACK_GET_THREAD_ID: // 31
        case LWS_CALLBACK_HTTP_BIND_PROTOCOL: // 49
        case LWS_CALLBACK_ADD_HEADERS: // 53
        case LWS_CALLBACK_CLIENT_HTTP_BIND_PROTOCOL: // 85
        case LWS_CALLBACK_HTTP_CONFIRM_UPGRADE: // 86
        case LWS_CALLBACK_EVENT_WAIT_CANCELLED: // 71
        case LWS_CALLBACK_VHOST_CERT_AGING: // 72
        case LWS_CALLBACK_CLIENT_HTTP_DROP_PROTOCOL: // 76
        case LWS_CALLBACK_WS_SERVER_DROP_PROTOCOL: // 78
        case LWS_CALLBACK_WS_CLIENT_DROP_PROTOCOL: // 80
        case LWS_CALLBACK_CONNECTING: // 105
            // Nothing to do but keeping empty cases on purpose
            break;

        default:
            vxlog_error("lws_callback_http case not handled: %d", reason);
            // TODO: cleanup?
            return -1;
    }

    return 0;
}

#endif
