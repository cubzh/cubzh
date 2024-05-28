//
//  LocalConnection.cpp
//  xptools
//
//  Created by Gaetan de Villele on 17/03/2022.
//

#include "LocalConnection.hpp"

// C++
#include <cassert>

// xptools
#include "vxlog.h"

using namespace vx;

LocalConnection::LocalConnection() :
_status(Connection::Status::IDLE),
_statusMutex(),
_thread(),
_threadShouldExit(false),
_threadShouldExitMutex(),
_peerConnection() {
    _thread = std::thread(&LocalConnection::_threadFunction, this);
}

LocalConnection::~LocalConnection() {
    if (isClosed() == false) {
        assert(false);
        vxlog_error("[~LocalConnection] connection is not closed");
    }
    _stopThread();
}

void LocalConnection::pushReceivedBytes(const Payload_SharedPtr& payload) {
    if (this->getStatus() != Status::OK) {
        vxlog_warning("[LocalConnection::write] pushing received bytes to a closed connection");
        return;
    }
    _receivedBytes.push(payload);
}

Connection::Status LocalConnection::getStatus() {
    std::lock_guard<std::mutex> lock(_statusMutex);
    return _status;
}

void LocalConnection::reset() {
    vxlog_error("it's not allowed to reset a LocalConnection");
}

// Note : `callback` is ignored here
void LocalConnection::connect() {
    {
        std::lock_guard<std::mutex> lock(_statusMutex);
        if (_status == Status::IDLE) {
            _status = Status::OK;
        } else {
            return;
        }
    }
    
    // notify connection's delegate
    std::shared_ptr<ConnectionDelegate> delegate = getDelegate().lock();
    if (delegate != nullptr) {
        delegate->connectionDidEstablish(*this);
    }
    
    // notify peer connection's delegate
    LocalConnection_SharedPtr peerConn = this->_peerConnection.lock();
    if (peerConn != nullptr) {
        peerConn->connect();
    }
}

bool LocalConnection::isClosed() {
    Status status = getStatus();
    return status == Status::CLOSED || status == Status::CLOSED_ON_ERROR || status == Status::CLOSED_INITIAL_CONNECTION_FAILURE;
}

bool LocalConnection::_isClosedNoMutex() {
    return _status == Status::CLOSED || _status == Status::CLOSED_ON_ERROR || _status == Status::CLOSED_INITIAL_CONNECTION_FAILURE;
}

void LocalConnection::close() {
    {
        std::lock_guard<std::mutex> lock(_statusMutex);
        if (_isClosedNoMutex()) {
            vxlog_error("can't close closed connection");
            return;
        }
        _status = Status::CLOSED;
    }
    
    LocalConnection_SharedPtr peerConn = _peerConnection.lock();
    if (peerConn != nullptr) {
        peerConn->close();
    }
    
    _stopThread();
    
    // notify delegate
    std::shared_ptr<ConnectionDelegate> delegate = getDelegate().lock();
    if (delegate != nullptr) {
        delegate->connectionDidClose(*this);
    }
}

void LocalConnection::closeOnError() {
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
    
    LocalConnection_SharedPtr peerConn = _peerConnection.lock();
    if (peerConn != nullptr) {
        peerConn->closeOnError();
    }
    
    _stopThread();
    
    // notify delegate
    std::shared_ptr<ConnectionDelegate> delegate = getDelegate().lock();
    if (delegate != nullptr) {
        delegate->connectionDidClose(*this);
    }
}
    
void LocalConnection::_threadFunction() {
    Payload_SharedPtr payload = nullptr;
    while (true) {
        {
            std::lock_guard<std::mutex> lock(_threadShouldExitMutex);
            if (this->_threadShouldExit == true) {
                return;
            }
        }
        if (_receivedBytes.pop(payload)) {
            std::shared_ptr<ConnectionDelegate> delegate = getDelegate().lock();
            if (delegate != nullptr) {
                delegate->connectionDidReceive(*this, payload);
                payload = nullptr;
            } else {
                vxlog_warning("[LocalConnection::_threadFunction] bytes are dropped");
            }
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
}

void LocalConnection::_stopThread() {
    if (_thread.joinable()) {
        {
            std::lock_guard<std::mutex> lock(_threadShouldExitMutex);
            this->_threadShouldExit = true;
        }
        _thread.join();
        vxlog_debug("[LocalConnection::_stopThread] %p", this);
    }
}

//

void LocalConnection::pushPayloadToWrite(const Payload_SharedPtr& p) {
    if (this->getStatus() != Status::OK) {
        vxlog_warning("[LocalConnection::write] writing in a closed connection");
        return;
    }
    
    LocalConnection_SharedPtr peerConn = _peerConnection.lock();
    if (peerConn != nullptr) {
        if (peerConn->isClosed() == false) {
            peerConn->pushReceivedBytes(p);
        } else {
            vxlog_warning("[LocalConnection::write] writing to closed peer");
            return;
        }
    } else {
        assert(false);
    }
}

size_t LocalConnection::write(char *buf, size_t len, bool& isFirstFragment, bool& partial) {
    return 0;
}

bool LocalConnection::doneWriting() {
    return true;
}

