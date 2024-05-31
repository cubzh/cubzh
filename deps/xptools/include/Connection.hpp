//
//  Connection.hpp
//  xptools
//
//  Created by Gaetan de Villele on 09/02/2022.
//

#pragma once

// C++
#include <string>
#include <memory>
#include <vector>
#include <functional>
#include <mutex>

#include "Channel.hpp"

namespace vx {

// client game <> WSConnection(lws/emscripten) <> [web] <> WSConnection(lws) <> game server
// client game <> LocalConnection <> LocalConnection <> game server

class ConnectionDelegate;
//typedef std::shared_ptr<ConnectionDelegate> ConnectionDelegate_SharedPtr;
//typedef std::weak_ptr<ConnectionDelegate> ConnectionDelegate_WeakPtr;

class Connection;
typedef std::shared_ptr<Connection> Connection_SharedPtr;

// Connection is one side of a 2-peer connection.
class Connection {
    
public:
    
    class Payload;
    typedef std::shared_ptr<Payload> Payload_SharedPtr;
    
    ///
    class Payload final {
    public:
        
        typedef uint16_t IDType;
        
        typedef enum {
            None = 0,
            PayloadID = 1,
            CreatedAt = 2,
            TravelHistory = 4,
        } Includes;
        
        typedef struct Step {
            std::string name; // step name (max size: 255)
            // not sent over the wire, when traveling from client to server
            // and vice versa, all timestamps in the history are set to 0
            // we're only interested in local step diffs.
            uint64_t timestamp;
            // NOTE: do not compute diff if previous step's timestamp == 0
            uint32_t diff; // elapsed milliseconds since previous step
            char pad[4];
        } Step;
        
        static Payload_SharedPtr create(char *content, size_t len, uint8_t includes = Includes::None);
        // creates a one byte payload that's not even supposed to be sent
        // used to trigger a meant to fail write operation, in order to close the connection.
        static Payload_SharedPtr createDummy();
        static Payload_SharedPtr decode(char *bytes, size_t len);
        static Payload_SharedPtr copy(const Payload_SharedPtr& p);
        
        ~Payload();
        
        // Returns start of _content
        char* getContent();
        
        // Returns start of _content
        char* getMetadata();
        
        // Adds a step in the travel history for debug
        void step(const std::string &name);
        
        // Displays as much info as possible,
        // based on included metadata and
        // Payload's current state.
        void debug();
        
        // size of _content
        size_t contentSize();
        
        // The header is what comes before content bytes,
        // _includes (1 byte) + metadata
        size_t metadataSize();
        
        // metadata size + content size
        size_t totalSize();
        
        // serializes _metadata if NULL
        // returns true on success, false otherwise
        bool createMetadataIfNull();
        
    private:
        Payload(char* bytes, size_t len, uint8_t includes = Includes::None);
        Payload();
        
        // Returns next Payload ID (thread safe)
        // Only used when including PayloadID
        static uint16_t _getNextID();
        static uint16_t _nextID;
        static std::mutex _nextIDMutex;
        
        // Cache to avoid re-computing header size
        // set to 0 to invalid
        size_t _metadataSizeCache;
        
        // _metadata when Payload is created
        // Set on first write call.
        char *_metadata;
        
        // Content bytes
        char *_content;
        size_t _len;
        
        // When decoding a Payload, _content
        // can be found within decoded bytes.
        // To avoid a realloc, when decoding,
        // we make _content point to where it starts
        // within _decoded.
        // When destroying a Payload, _decoded should
        // be freed if not NULL instead of _content.
        char *_decoded;
        
        // Only used when including CreatedAt
        uint64_t _createdAt; // ms timestamp
        
        // Only used when including TravelHistory
        std::vector<Step> _steps;
        
        // Only used when including PayloadID
        IDType _id;
        
        // A mask to indicate optional
        // metadata, included in the Payload.
        // How the Payload is structured:
        // _includes
        // METADATA
        //   _id (IDType) (optional)
        //   _createdAd (uint64_t) (optional)
        //   nbSteps (uint8_t)
        //   nbSteps x (uint8_t + name_len + uint32_t)
        // CONTENT BYTES
        uint8_t _includes;
    };
    
    ///
    enum class Status {
        IDLE,
        OK,
        CLOSED_ON_ERROR,
        CLOSED_INITIAL_CONNECTION_FAILURE,
        CLOSED // expected
    };
    
    /// establishes connection
    /// Note (gdevillele) : this should probably be removed as it's not the
    ///                     connection's responsability to be established.
    virtual void connect() = 0;
    
    virtual void reset() = 0;
    virtual void close() = 0;
    virtual void closeOnError() = 0;
    
    /// returns current Connection status
    virtual Status getStatus() = 0;
    
    // returns true if the connection is closed
    virtual bool isClosed() = 0;
    
    ///
    inline void setDelegate(std::weak_ptr<ConnectionDelegate> delegate) { _delegate = delegate; }
    
    ///
    inline std::weak_ptr<ConnectionDelegate> getDelegate() { return _delegate; }
    
    // ------------------
    // CONNECTION WRITER
    // ------------------
    
    /// Pushes Payload to be written
    virtual void pushPayloadToWrite(const Payload_SharedPtr& p) = 0;
    
    // Writes as much as possible of current Payload in given buffer.
    // isFirstFragment: indicates if first fragment of Payload's been returned
    // partial: if true, means Payload has been partially written
    // Returns size written
    virtual size_t write(char *buf, size_t len, bool& isFirstFragment, bool& partial) = 0;
    
    virtual bool doneWriting() = 0;
    
private:
    
    ///
    std::weak_ptr<ConnectionDelegate> _delegate;
};

///  Interface
class ConnectionDelegate {
public:
    ///
    virtual void connectionDidEstablish(Connection& conn) = 0;
    
    /// Delegate owns the Payload (is responsible for its deletion)
    virtual void connectionDidReceive(Connection& conn, const Connection::Payload_SharedPtr& payload) = 0;
    
    /// NOTE: The connection can be closed while never been established,
    /// it's possible to look at the status to get that information.
    virtual void connectionDidClose(Connection& conn) = 0;
};

} // namespace vx
