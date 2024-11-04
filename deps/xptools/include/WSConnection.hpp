//
//  WSConnection.hpp
//  xptools
//
//  Created by Gaetan de Villele on 01/03/2022.
//

#pragma once

// C++
#include <thread>

// websockets
#if defined(__VX_USE_LIBWEBSOCKETS)
// libwebsockets
#include "libwebsockets.h"
#endif

// emscripten API
#if defined(__VX_PLATFORM_WASM)
#include <emscripten/websocket.h>
#endif

// xptools
#include "Channel.hpp"
#include "Connection.hpp"
#include "WSBackend.hpp"

namespace vx {

class WSConnection;
typedef std::shared_ptr<WSConnection> WSConnection_SharedPtr;
typedef std::weak_ptr<WSConnection> WSConnection_WeakPtr;

class WSConnection final : public Connection {
public:

    static WSConnection_SharedPtr make(const std::string& scheme,
                                       const std::string& addr,
                                       const uint16_t& port);

    ~WSConnection();

    Status getStatus() override;

    void reset() override;
    void close() override;
    void closeOnError() override;

    // sets Status == OK
    // called by WSService
    void established();

    bool isClosed() override;
    void connect() override;

    // accessors
    const std::string& getHost() const;
    const uint16_t& getPort() const;
    const bool& getSecure() const;
    std::string getURL() const;

#if defined(__VX_USE_LIBWEBSOCKETS) || defined(__VX_PLATFORM_WASM)
    WSBackend getWsi();
    // std::mutex& getWsiMutex();
    // modifiers
    void setWsi(WSBackend wsi);
#endif

    /// notify the connection that it received data
    /// bytes must be copied!
    void receivedBytes(char *bytes, const size_t len, const bool isFinalFragment);

    ///
    void setIsWriting(const bool isWriting);

    ///
    bool isWriting();

    // ------------------
    // CONNECTION WRITER
    // ------------------

    /// Pushes Payload to be written
    void pushPayloadToWrite(const Payload_SharedPtr& p) override;

    // Writes as much as possible in given buffer
    // Returns size written
    size_t write(char *buf, size_t len, bool& isFirstFragment, bool& partial) override;

    bool doneWriting() override;

private:

    /// private constructor
    WSConnection();

    // Private methods

    ///
    void init(const WSConnection_SharedPtr& ref,
              const std::string& scheme,
              const std::string& addr,
              const uint16_t& port);

    ///
    void _threadFunction();

    ///
    bool _isClosedNoMutex();

    /// Returns payload to write,
    /// loading next one in line if needed.
    /// Returns NULL if there's nothing to write.
    Connection::Payload_SharedPtr _getPayloadToWrite();

    // Private fields

    ///
    WSConnection_WeakPtr _weakSelf;

    /// address of server to connect to
    std::string _serverAddr;

    /// server port to connect to
    uint16_t _serverPort;

    /// indicate whether SSL is used
    bool _secure;

    /// Indicates wether the connection is closed
    Status _status;
    std::mutex _statusMutex;

    // REQUIRED ONLY WHEN USING LIBWEBSOCKETS:

#if defined(__VX_USE_LIBWEBSOCKETS) || defined(__VX_PLATFORM_WASM)
    /// lws connection handler
    WSBackend _wsi;
    std::mutex _wsiMutex;
#endif

    /// buffer for received bytes
    std::string _receivedBytesBuffer;

    /// `true` means "not currently writing
    bool _isWriting;

    ///
    std::mutex _isWritingMutex;

    ///
    Channel<Connection::Payload_SharedPtr> _payloadsToWrite;

    ///
    Connection::Payload_SharedPtr _payloadBeingWritten;

    // Total bytes written for current Payload
    // (including header and metadata)
    size_t _written;

    // PLATFORM SPECIFIC

    void _init();
    void _connect();
    void _writePayload(const Payload_SharedPtr& p);
    // void _readPayload(); // reads next payload
    void _close();
    void _destroy();

    void *_platformObject;
    void _attachPlatformObject(void *o);
    void _detachPlatformObject();
};

} // namespace vx
