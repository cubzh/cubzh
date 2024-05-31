//
//  WSServerConnection.hpp
//  xptools
//
//  Created by Gaetan de Villele on 17/03/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#pragma once

// xptools
#include "WSTypes.hpp"
#include "Connection.hpp"
#include "Channel.hpp"

#include "WSBackend.hpp"

namespace vx {

#ifdef __VX_USE_LIBWEBSOCKETS

class WSServer;
class WSServerConnection;
typedef std::shared_ptr<WSServerConnection> WSServerConnection_SharedPtr;
typedef std::weak_ptr<WSServerConnection> WSServerConnection_WeakPtr;

class WSServerConnection final : public Connection {
public:
    
    // --------------------------------------------------
    // Constructor / Destructor
    // --------------------------------------------------
    
    WSServerConnection(WSServer* parentServer, WSBackend wsi);
    ~WSServerConnection();
    
    // --------------------------------------------------
    // "Connection" interface implementation
    // --------------------------------------------------
    
    void connect() override;
    
    void reset() override;
    void close() override;
    void closeOnError() override;
    
    bool isClosed() override;
    
    Connection::Status getStatus() override;
    
    ///
    WSBackend getWsi();
    
    /// Notify the connection that it received data.
    /// (bytes must be copied!)
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
    
    ///
    WSBackend _wsi; // weak ref
    std::mutex _wsiMutex;
    
    ///
    void _setWsi(WSBackend wsi);
    
    ///
    bool _isClosedNoMutex();
    
    /// Returns payload to write,
    /// loading next one in line if needed.
    /// Returns NULL if there's nothing to write.
    Payload_SharedPtr _getPayloadToWrite();
    
    ///
    WSServer* _server;
    
    ///
    Channel<Connection::Payload_SharedPtr> _payloadsToWrite;
    
    ///
    Connection::Payload_SharedPtr _payloadBeingWritten;
    
    /// Indicates wether the connection is closed
    Status _status;
    std::mutex _statusMutex;
    
    /// buffer for received bytes
    std::string _receivedBytesBuffer;
    
    /// `true` means currently writing
    bool _isWriting;
    
    ///
    std::mutex _isWritingMutex;
    
    // Total bytes written for current Payload
    // (including header and metadata)
    size_t _written;
};

#endif

} // namespace vx
