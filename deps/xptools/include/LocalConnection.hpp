//
//  LocalConnection.hpp
//  xptools
//
//  Created by Gaetan de Villele on 22/02/2022.
//

#pragma once

// C++
#include <mutex>
#include <thread>

// vx
#include "Channel.hpp"
#include "Connection.hpp"

namespace vx {

class LocalConnection;
typedef std::shared_ptr<LocalConnection> LocalConnection_SharedPtr;

class LocalConnection final : public Connection {
public:
    
    ///
    LocalConnection();
    
    ///
    ~LocalConnection();
    
    ///
    inline void setPeerConnection(LocalConnection_SharedPtr peerConn) { _peerConnection = peerConn; }
    
    ///
    void pushReceivedBytes(const Payload_SharedPtr& payload);
    
    Status getStatus() override;
    
    void reset() override;
    void close() override;
    void closeOnError() override;
    
    bool isClosed() override;
    void connect() override;
    
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
    
    // methods
    
    ///
    void _threadFunction();
    
    ///
    void _stopThread();
    
    ///
    bool _isClosedNoMutex();
    
    // fields
    
    /// Indicates whether the connection is closed
    Status _status;
    std::mutex _statusMutex;
    
    /// thread processing the received bytes
    std::thread _thread;
    bool _threadShouldExit;
    std::mutex _threadShouldExitMutex;
    
    /// Bytes received from the other side.
    Channel<Payload_SharedPtr> _receivedBytes;
    
    /// Weak pointer to the "other side" of the connection stream.
    std::weak_ptr<LocalConnection> _peerConnection;
};

} // namespace vx
