//
//  WSConnection.cpp
//  xptools
//
//  Created by Gaetan de Villele on 17/03/2022.
//

#include "WSConnection.hpp"

// C++
#include <thread>
#include <cassert>

// xptools
#include "vxlog.h"
#include "ThreadManager.hpp"
#include "WSService.hpp"

using namespace vx;

// --------------------------------------------------
//
// MARK: - Public -
//
// --------------------------------------------------

WSConnection_SharedPtr WSConnection::make(const std::string& scheme,
                                          const std::string& addr,
                                          const uint16_t& port,
                                          const std::string& path) {
    WSConnection_SharedPtr conn(new WSConnection());
    conn->init(conn, scheme, addr, port, path);
    return conn;
}

WSConnection::WSConnection() : Connection(),
_weakSelf(),
_serverAddr(),
_serverPort(),
_serverPath(),
_secure(false),
_status(Status::IDLE),
_statusMutex(),
#ifdef __VX_USE_LIBWEBSOCKETS
_wsi(nullptr),
#else // EMSCRIPTEN
_wsi(0),
#endif
_wsiMutex(),
_receivedBytesBuffer(),
_isWriting(false),
_isWritingMutex(),
_payloadsToWrite(),
_payloadBeingWritten(nullptr),
_written(0) {
#ifdef __VX_USE_LIBWEBSOCKETS
#else // EMSCRIPTEN
    if (emscripten_websocket_is_supported() == false) {
        vxlog_error("[WSConnection::WSConnection] Websockets are not supported by EMSCRIPTEN here!");
    }
#endif
}

WSConnection::~WSConnection() {
    
    // free all payloads waiting, if there are any
    _payloadsToWrite.clear();
    _payloadBeingWritten = nullptr;
    
#ifdef __VX_USE_LIBWEBSOCKETS
#else // EMSCRIPTEN
#endif
    vxlog_debug("[WSConnection] deleted");
}

Connection::Status WSConnection::getStatus() {
    std::lock_guard<std::mutex> lock(_statusMutex);
    return _status;
}

#ifdef __VX_USE_LIBWEBSOCKETS

#else // EMSCRIPTEN
EM_BOOL onopen(int eventType,
               const EmscriptenWebSocketOpenEvent *websocketEvent,
               void *userdata) {
    WSConnection* wsConn = reinterpret_cast<WSConnection*>(userdata);
    vxlog_debug("[WSConnection] onopen (%p)", wsConn);
    if (wsConn == nullptr) {
        return false;
    }
    wsConn->established();
    std::shared_ptr<ConnectionDelegate> delegate = wsConn->getDelegate().lock();
    if (delegate != nullptr) {
        delegate->connectionDidEstablish(*wsConn);
    }
    return true;
}

EM_BOOL onerror(int eventType,
                const EmscriptenWebSocketErrorEvent *websocketEvent,
                void *userdata) {
    vxlog_debug("[WSConnection] onerror (%d) (%p) (%p)", eventType, websocketEvent, userdata);
    return true;
}

EM_BOOL onclose(int eventType,
                const EmscriptenWebSocketCloseEvent *websocketEvent,
                void *userdata) {
    WSConnection* wsConn = reinterpret_cast<WSConnection*>(userdata);
    vxlog_debug("[WSConnection] onclose %d %d %s", eventType, websocketEvent->code, websocketEvent->reason);
    if (wsConn == nullptr) {
        return false;
    }
    
    // Websocket close codes : https://github.com/Luka967/websocket-close-codes
    if (websocketEvent->code != 1000) {
        // error
        wsConn->closeOnError();
    } else {
        wsConn->close();
    }
    return true;
}

EM_BOOL onmessage(int eventType,
                  const EmscriptenWebSocketMessageEvent *websocketEvent,
                  void *userdata) {
    WSConnection* wsConn = reinterpret_cast<WSConnection*>(userdata);
    // vxlog_debug("[WSConnection] onmessage (%p) (%d bytes)", wsConn, websocketEvent->numBytes);
    if (wsConn == nullptr) {
        return false;
    }
    assert(websocketEvent->isText == false);
    wsConn->receivedBytes(const_cast<char*>(reinterpret_cast<const char*>(websocketEvent->data)),
                          websocketEvent->numBytes,
                          true); // hardcoded value for `isFinalFragment`
    return true;
}
#endif

void WSConnection::connect() {
#ifdef __VX_USE_LIBWEBSOCKETS
    
#else // EMSCRIPTEN
    
    // free _wsi if it was allocated
    emscripten_websocket_close(_wsi, 1000, ""); // 1000 means CLOSE_NORMAL
    emscripten_websocket_delete(_wsi);
    
    // construct string with scheme, address and port
    const std::string urlScheme = _secure ? "wss" : "ws";
    std::string url = urlScheme + "://" + _serverAddr + ":" + std::to_string(_serverPort);
    if (_serverPath != "") {
        url = url + "/" + _serverPath;
    }
    // vxlog_debug("[WSConnection::connect] %s", url.c_str());
    EmscriptenWebSocketCreateAttributes ws_attrs = {
        url.c_str(),
        NULL, //"binary",
        EM_FALSE // on main thread
    };
    _wsi = emscripten_websocket_new(&ws_attrs);
    emscripten_websocket_set_onopen_callback(_wsi, this, onopen);
    emscripten_websocket_set_onerror_callback(_wsi, this, onerror);
    emscripten_websocket_set_onclose_callback(_wsi, this, onclose);
    emscripten_websocket_set_onmessage_callback(_wsi, this, onmessage);
#endif
    // send WSConnection to WSService for processing
    WSService::shared()->requestWSConnection(_weakSelf.lock());
}

bool WSConnection::isClosed() {
    Status status = getStatus();
    return (status == Status::CLOSED ||
            status == Status::CLOSED_ON_ERROR ||
            status == Status::CLOSED_INITIAL_CONNECTION_FAILURE);
}

bool WSConnection::_isClosedNoMutex() {
    return (_status == Status::CLOSED ||
            _status == Status::CLOSED_ON_ERROR ||
            _status == Status::CLOSED_INITIAL_CONNECTION_FAILURE);
}

void WSConnection::reset() {
    {
        std::lock_guard<std::mutex> lock(_statusMutex);
        _status = Status::IDLE;
    }
    
    // free all payloads waiting, if there are any
    _payloadsToWrite.clear();
    _payloadBeingWritten = nullptr;
    _written = 0;
    
    _receivedBytesBuffer.clear();
    
#ifdef __VX_USE_LIBWEBSOCKETS
    setWsi(nullptr);
#else
    setWsi(0);
#endif
}

void WSConnection::established() {
    std::lock_guard<std::mutex> lock(_statusMutex);
    if (_status != Status::IDLE) {
        // ws connection is already closed, we do noting and return
        vxlog_error("[WSConnection::established] connection status expected to be IDLE");
        return;
    }
    _status = Status::OK;
}

void WSConnection::close() {
    {
        std::lock_guard<std::mutex> lock(_statusMutex);
        if (_isClosedNoMutex()) {
            // ws connection is already closed, we do noting and return
            vxlog_error("[WSConnection::close] connection is already closed");
            return;
        }
        _status = Status::CLOSED;
    }

#if defined(__VX_USE_LIBWEBSOCKETS)
    
    // Cancel polling of WSService.
    // This will make the lws callback function trigger, it will notice the
    // connection has been closed and disconnect the underlying TCP connection.
    _payloadsToWrite.push(Payload::createDummy());
    WSService::shared()->scheduleWSConnectionWrite(_weakSelf.lock());

#else // __VX_NETWORKING_EMSCRIPTEN
    
    emscripten_websocket_close(_wsi, 1000, ""); // 1000 means CLOSE_NORMAL
    emscripten_websocket_delete(_wsi);
    
#endif
    
    // notify delegate
    std::shared_ptr<ConnectionDelegate> delegate = getDelegate().lock();
    if (delegate != nullptr) {
        delegate->connectionDidClose(*this);
    }
}

void WSConnection::closeOnError() {
    {
        std::lock_guard<std::mutex> lock(_statusMutex);
        if (_isClosedNoMutex()) {
            vxlog_error("can't close closed connection");
            return;
        }
        
        if (_status == Status::IDLE) {
            _status = Status::CLOSED_INITIAL_CONNECTION_FAILURE;
            // vxlog_debug("WSConnection::closeOnError -> INITIAL CONNECTION FAILURE");
        } else {
            _status = Status::CLOSED_ON_ERROR;
            vxlog_debug("WSConnection::closeOnError -> ERROR");
        }
    }
    
    // notify delegate
    std::shared_ptr<ConnectionDelegate> delegate = getDelegate().lock();
    if (delegate != nullptr) {
        delegate->connectionDidClose(*this);
    }
}

const std::string& WSConnection::getHost() const {
    return _serverAddr;
}

const uint16_t& WSConnection::getPort() const {
    return _serverPort;
}

const std::string& WSConnection::getPath() const {
    return _serverPath;
}

const bool& WSConnection::getSecure() const {
    return _secure;
}

WSBackend WSConnection::getWsi() {
    std::lock_guard<std::mutex> lock(_wsiMutex);
    return _wsi;
}

//std::mutex& WSConnection::getWsiMutex() {
//    return _wsiMutex;
//}

void WSConnection::setWsi(WSBackend wsi) {
    std::lock_guard<std::mutex> lock(_wsiMutex);
    _wsi = wsi;
}

Connection::Payload_SharedPtr WSConnection::_getPayloadToWrite() {
    // payload to write should be in _payloadBeingWritten
    
    if (_payloadBeingWritten != nullptr && 
        _written == _payloadBeingWritten->totalSize()) {
        _payloadBeingWritten = nullptr;
    }
    
    if (_payloadBeingWritten == nullptr) {
        // try popping payload from channel
        _payloadsToWrite.pop(_payloadBeingWritten);
        
        // _payloadBeingWritten remains NULL if nothing was popped
        
        if (_payloadBeingWritten != nullptr) {
            _written = 0;
            _payloadBeingWritten->step("start writing out (client)");
        }
    }
    
    return _payloadBeingWritten;
}

void WSConnection::receivedBytes(char *bytes,
                                 const size_t len,
                                 const bool isFinalFragment) {
    // append received bytes
    if (len > 0) {
        _receivedBytesBuffer.append(bytes, len);
    }
    
    if (isFinalFragment) {
        // notify delegate
        std::shared_ptr<ConnectionDelegate> delegate = getDelegate().lock();
        if (delegate != nullptr) {
            char *bytes = reinterpret_cast<char*>(malloc(_receivedBytesBuffer.size()));
            if (bytes != nullptr) {
                memcpy(bytes, _receivedBytesBuffer.c_str(), _receivedBytesBuffer.size());

                Payload_SharedPtr pld = Payload::decode(bytes, _receivedBytesBuffer.size());
                
                pld->step("WSConnection::receivedBytes");
                
                delegate->connectionDidReceive(*this, pld);
            } else {
                vxlog_error("[WSConnection::receivedBytes] dropped bytes");
            }
        }
        _receivedBytesBuffer.clear();
    }
}

void WSConnection::receivedWorkspace(char *bytes,
                                     const size_t len,
                                     const bool isFinalFragment) {
    std::shared_ptr<ConnectionDelegate> delegate = getDelegate().lock();
    if (delegate != nullptr) {
        delegate->connectionDidReceiveWorkspace(*this, bytes);
    }
}

void WSConnection::setIsWriting(const bool isWriting) {
    std::lock_guard<std::mutex> lock(_isWritingMutex);
    _isWriting = isWriting;
}

bool WSConnection::isWriting() {
    std::lock_guard<std::mutex> lock(_isWritingMutex);
    return _isWriting;
}

// --------------------------------------------------
// MARK: - Payload Writer -
// --------------------------------------------------

void WSConnection::pushPayloadToWrite(const Payload_SharedPtr& p) {
    if (this->getStatus() != Status::OK) {
        vxlog_warning("[WSConnection::pushPayloadToWrite] writing in a closed connection");
        return;
    }
    // push Payload to channel
    // they will be read by LWS callback
    _payloadsToWrite.push(p);
    
    // notify WSService that bytes are waiting to be written
    WSService::shared()->scheduleWSConnectionWrite(_weakSelf.lock());
}

size_t WSConnection::write(char *buf, size_t len, bool& isFirstFragment, bool& partial) {
    isFirstFragment = false;
    partial = true;
    
    Payload_SharedPtr payload = _getPayloadToWrite();
    if (payload == nullptr) {
        return 0;
    }
    
    // TODO: should createMetadataIfNull be thread safe?
    if (payload->createMetadataIfNull() == false) {
        return 0;
    }
    
    char *cursor = nullptr;
    isFirstFragment = _written == 0;
    
    size_t toWrite;
    size_t n = 0;
    bool exit = false;
    
    cursor = buf;
    
    size_t metadataSize = payload->metadataSize();
    
    if (_written < metadataSize) {
        toWrite = metadataSize - _written;
        if (toWrite > len) {
            toWrite = len;
            exit = true;
        }
        
        memcpy(cursor, payload->getMetadata() + _written, toWrite);
        
        cursor += toWrite;
        n += toWrite;
        _written += toWrite;
    }
    
    if (exit) {
        return n;
    }
    
    size_t contentWritten = _written - metadataSize;
    
    toWrite = payload->contentSize() - contentWritten;
    if (toWrite > (len-n)) { toWrite = (len-n); } // (len-n) is the current "write capacity"
    
    // NOTE: we could compress (using zlib deflate) when size is big enough (>~42 bytes?)
    // https://stackoverflow.com/a/63699295
    memcpy(cursor, payload->getContent() + contentWritten, toWrite);
    n += toWrite;
    _written += toWrite;
    
    partial = _written < payload->totalSize();
    return n;
}

bool WSConnection::doneWriting() {
    return _getPayloadToWrite() == nullptr;
}

// --------------------------------------------------
// MARK: - Private -
// --------------------------------------------------

void WSConnection::init(const WSConnection_SharedPtr& ref,
                        const std::string& scheme,
                        const std::string& addr,
                        const uint16_t& port,
                        const std::string& path) {
    assert(scheme == "ws" || scheme == "wss");
    _weakSelf = ref;

    // _scheme = scheme;
    _serverAddr.assign(addr);
    _serverPort = port;
    _serverPath.assign(path);
    if (scheme == "wss") { _secure = true; }
}

#ifdef __VX_USE_LIBWEBSOCKETS
#else // EMSCRIPTEN
#endif
