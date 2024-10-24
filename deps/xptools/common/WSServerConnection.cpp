//
//  WSServerConnection.cpp
//  xptools
//
//  Created by Gaetan de Villele on 18/03/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#include "WSServerConnection.hpp"

// xptools
#include "vxlog.h"
#include "WSServer.hpp"

using namespace vx;

#if defined(__VX_USE_LIBWEBSOCKETS)

// --------------------------------------------------
// Constructor / Destructor
// --------------------------------------------------

WSServerConnection::WSServerConnection(WSServer* parentServer, WSBackend wsi) :
Connection(),
_wsi(wsi),
_wsiMutex(),
_server(parentServer),
_payloadsToWrite(),
_status(Connection::Status::IDLE),
_statusMutex(),
_receivedBytesBuffer(),
_isWriting(false),
_isWritingMutex(),
_written(0) {}

WSServerConnection::~WSServerConnection() {}

// --------------------------------------------------
// "Connection" interface implementation
// --------------------------------------------------

void WSServerConnection::connect() {
    // this is not used here, as the connection is created by the WSServer
    vxlog_error("[WSServerConnection::connect] this function should not be used");
}

bool WSServerConnection::isClosed() {
    Status status = getStatus();
    return status == Status::CLOSED || status == Status::CLOSED_ON_ERROR || status == Status::CLOSED_INITIAL_CONNECTION_FAILURE;
}

bool WSServerConnection::_isClosedNoMutex() {
    return _status == Status::CLOSED || _status == Status::CLOSED_ON_ERROR || _status == Status::CLOSED_INITIAL_CONNECTION_FAILURE;
}

void WSServerConnection::reset() {
    vxlog_error("it's not allowed to reset a WSServerConnection");
}

void WSServerConnection::close() {
    {
        std::lock_guard<std::mutex> lock(_statusMutex);
        if (_isClosedNoMutex()) {
            vxlog_error("can't close closed connection");
            return;
        }
        _status = Status::CLOSED;
    }
    
    _setWsi(nullptr);
    
    // notify delegate
    std::shared_ptr<ConnectionDelegate> delegate = getDelegate().lock();
    if (delegate != nullptr) {
        delegate->connectionDidClose(*this);
    }
}

void WSServerConnection::closeOnError() {
    {
        std::lock_guard<std::mutex> lock(_statusMutex);
        if (_isClosedNoMutex()) {
            vxlog_error("can't close closed connection");
            return;
        }
        if (_status == Status::IDLE) {
            _status = Status::CLOSED_INITIAL_CONNECTION_FAILURE;
        } else {
            _status = Status::CLOSED_ON_ERROR;
        }
    }
    
    _setWsi(nullptr);
    
    // notify delegate
    std::shared_ptr<ConnectionDelegate> delegate = getDelegate().lock();
    if (delegate != nullptr) {
        delegate->connectionDidClose(*this);
    }
}

Connection::Status WSServerConnection::getStatus() {
    std::lock_guard<std::mutex> lock(_statusMutex);
    return _status;
}

lws* WSServerConnection::getWsi() {
    std::lock_guard<std::mutex> lock(_wsiMutex);
    return _wsi;
}

void WSServerConnection::_setWsi(lws *wsi) {
    std::lock_guard<std::mutex> lock(_wsiMutex);
    _wsi = wsi;
}

void WSServerConnection::receivedBytes(char *bytes,
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
                
                pld->step("WSServerConnection::receivedBytes");
                
                delegate->connectionDidReceive(*this, pld);
            } else {
                vxlog_error("[WSConnection::receivedBytes] dropped bytes");
            }
        }
        _receivedBytesBuffer.clear();
    }
}

void WSServerConnection::setIsWriting(const bool isWriting) {
    std::lock_guard<std::mutex> lock(_isWritingMutex);
    _isWriting = isWriting;
}

bool WSServerConnection::isWriting() {
    std::lock_guard<std::mutex> lock(_isWritingMutex);
    return _isWriting;
}

// --------------------------------------------------
// MARK: - Payload Writer -
// --------------------------------------------------

Connection::Payload_SharedPtr WSServerConnection::_getPayloadToWrite() {
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
            _payloadBeingWritten->step("start writing out (server)");
        }
    }
    
    return _payloadBeingWritten;
}

void WSServerConnection::pushPayloadToWrite(const Payload_SharedPtr& p) {
    
    p->step("WSServerConnection::write");
    
    // push Payload to channel
    // they will be read by LWS callback
    _payloadsToWrite.push(p);
    
    // notify WSServer that some bytes are waiting to be written
    _server->scheduleWrite(this);
}

size_t WSServerConnection::write(char *buf, size_t len, bool& isFirstFragment, bool& partial) {
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

bool WSServerConnection::doneWriting() {
    return _getPayloadToWrite() == nullptr;
}

#endif
