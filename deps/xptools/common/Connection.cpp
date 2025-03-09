//
//  Connection.cpp
//  xptools
//
//  Created by Gaetan de Villele on 17/03/2022.
//

#include "Connection.hpp"

// C++
#include <chrono>
#include <cstring>

#include "vxlog.h"

#define PAYLOAD_DIFF_NOT_POSSIBLE UINT32_MAX

using namespace vx;

//
// Payload
//

Connection::Payload::IDType Connection::Payload::_nextID = 0;

std::mutex Connection::Payload::_nextIDMutex;

uint16_t Connection::Payload::_getNextID() {
    const std::lock_guard<std::mutex> lock(_nextIDMutex);
    ++_nextID;
    return _nextID;
}

Connection::Payload_SharedPtr Connection::Payload::create(char *content, size_t len, uint8_t includes) {
    return Payload_SharedPtr(new Payload(content, len, includes));
}

Connection::Payload_SharedPtr Connection::Payload::createDummy() {
    size_t len = 1;
    char *content = static_cast<char*>(malloc(len));
    return Payload_SharedPtr(new Payload(content, len, Includes::None));
}

Connection::Payload_SharedPtr Connection::Payload::decode(char *bytes, size_t len) {
    
    if (bytes == nullptr) return nullptr;
    if (len < 1) return nullptr;
    
    Payload *p = new Payload();
    
    p->_decoded = bytes;
    p->_decodedLen = len;
    char *cursor = p->_decoded;
    
    memcpy(&p->_includes, cursor, sizeof(uint8_t));
    cursor += sizeof(uint8_t);
    
    if (p->_includes & Includes::PayloadID) {
        memcpy(&p->_id, cursor, sizeof(IDType));
        cursor += sizeof(IDType);
    }
    
    if (p->_includes & Includes::CreatedAt) {
        memcpy(&p->_createdAt, cursor, sizeof(uint64_t));
        cursor += sizeof(uint64_t);
    }
    
    if (p->_includes & Includes::TravelHistory) {
        
        p->_steps = std::vector<Step>();
        uint8_t nbSteps = 0;
        memcpy(&nbSteps, cursor, sizeof(uint8_t));
        cursor += sizeof(uint8_t);
        
        uint8_t nameSize;
        char nameBuf[256];
        
        for (uint8_t i = 0; i < nbSteps; ++i) {
            Step s;
            s.timestamp = 0;
            
            memcpy(&nameSize, cursor, sizeof(uint8_t));
            cursor += sizeof(uint8_t);
            
            memcpy(nameBuf, cursor, nameSize);
            cursor += nameSize;
            nameBuf[nameSize] = '\0';
            s.name = std::string(nameBuf);
            
            memcpy(&s.diff, cursor, sizeof(uint32_t));
            cursor += sizeof(uint32_t);
            
            p->_steps.push_back(s);
        }
    }
    
    // content starts where cursor is
    p->_content = cursor;
    p->_len = len - static_cast<size_t>(cursor - bytes);

    return Payload_SharedPtr(p);
}

Connection::Payload_SharedPtr Connection::Payload::copy(const Payload_SharedPtr& p) {
    
    if (p == nullptr) return nullptr;
    
    Payload *copy = new Payload();
    copy->_includes = p->_includes;
    copy->_metadataSizeCache = 0;
    copy->_metadata = nullptr;
    
    copy->_createdAt = p->_createdAt;
    copy->_id = p->_id;
    
    if (p->_content == nullptr) {
        copy->_content = nullptr;
        copy->_len = 0;
    } else {
        copy->_content = static_cast<char*>(malloc(p->_len));
        copy->_len = p->_len;
        memcpy(copy->_content, p->_content, copy->_len);
    }
    
    if (copy->_includes & Includes::TravelHistory) {
        copy->_steps = p->_steps;
    }
    
    return Payload_SharedPtr(copy);
}

Connection::Payload::Payload(char* bytes, size_t len, uint8_t includes) {
    _includes = includes;
    _content = bytes;
    _decoded = nullptr;
    _len = len;
    _metadataSizeCache = 0;
    _metadata = nullptr;
    _createdAt = 0;
    _id = 0;
    
    if (_includes & Includes::PayloadID) {
        _id = _getNextID();
    }
    
    if (_includes & Includes::CreatedAt) {
        using namespace std::chrono;
        _createdAt = static_cast<uint64_t>(duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count());
    }
    
    if (_includes & Includes::TravelHistory) {
        _steps = std::vector<Step>();
    }
}

bool Connection::Payload::createMetadataIfNull() {
    if (_metadata == nullptr) { // serialize metadata
        char *cursor = nullptr;
        
        _metadata = static_cast<char*>(malloc(metadataSize()));
        
        cursor = _metadata;
        
        memcpy(cursor, &_includes, sizeof(uint8_t));
        cursor += sizeof(uint8_t);
        
        if (_includes & Includes::PayloadID) {
            memcpy(cursor, &_id, sizeof(IDType));
            cursor += sizeof(IDType);
        }
        
        if (_includes & Includes::CreatedAt) {
            memcpy(cursor, &_createdAt, sizeof(uint64_t));
            cursor += sizeof(uint64_t);
        }
        
        if (_includes & Includes::TravelHistory) {
            
            if (_steps.size() > 255) {
                vxlog_error("Too many Payload steps");
                return false;
            }
            
            const uint8_t steps = static_cast<uint8_t>(_steps.size());
            memcpy(cursor, &steps, sizeof(uint8_t));
            cursor += sizeof(uint8_t);
            
            uint8_t nameLen = 0;
            for (Step step : _steps) {
                nameLen = static_cast<uint8_t>(step.name.length());
                memcpy(cursor, &nameLen, sizeof(uint8_t));
                cursor += sizeof(uint8_t);
                
                memcpy(cursor, step.name.c_str(), nameLen);
                cursor += nameLen;
                
                memcpy(cursor, &step.diff, sizeof(uint32_t));
                cursor += sizeof(uint32_t);
            }
        }
    }
    return true;
}

Connection::Payload::Payload() {
    _includes = Includes::None;
    _content = nullptr;
    _decoded = nullptr;
    _len = 0;
    _metadataSizeCache = 0;
    _metadata = nullptr;
    _createdAt = 0;
    _id = 0;
}

Connection::Payload::~Payload() {
    if (_content != nullptr) {
        if (_decoded != nullptr) {
            free(_decoded);
            _decoded = nullptr;
        } else {
            free(_content);
        }
        _content = nullptr;
    }
    _len = 0;
    if (_metadata != nullptr) {
        free(_metadata);
        _metadata = nullptr;
    }
}

void Connection::Payload::step(const std::string &name) {
    
    // do not add step if Payload does not support travel history
    if ((_includes & Includes::TravelHistory) == 0) { return; }
    if (name.length() > 255) {
        vxlog_error("Connection::Payload::step - name too big (%s)", name.c_str());
        return;
    }
    
    using namespace std::chrono;
    const uint64_t now = static_cast<uint64_t>(duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count());

    Step step = {name, now, 0};
    
    if (_steps.size() > 0) {
        const uint64_t ts = _steps.back().timestamp;
        if (ts != 0) {
            step.diff = static_cast<uint32_t>(now - ts);
        } else {
            step.diff = PAYLOAD_DIFF_NOT_POSSIBLE;
        }
    }
    
    _steps.push_back(step);
}

void Connection::Payload::debug() {
    // return if no metadata for debug
    if (_includes == Includes::None) { return; }
    
    vxlog_trace("----- PAYLOAD -----");
    
    if (_includes & Includes::PayloadID) {
        vxlog_trace("    ID: %hu", _id);
    }
    
    if (_includes & Includes::CreatedAt) {
        using namespace std::chrono;
        const uint64_t now = static_cast<uint64_t>(duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count());
        vxlog_trace("    CREATED AT: %llu (%llu ms ago)", _createdAt, now - _createdAt);
    }
    
    if (_includes & Includes::TravelHistory) {
        vxlog_trace("    STEPS:");
        for (Step s : _steps) {
            if (s.diff == PAYLOAD_DIFF_NOT_POSSIBLE) {
                vxlog_trace("        - NETWORK - %s", s.name.c_str());
            } else {
                vxlog_trace("        - %4u ms - %s", s.diff, s.name.c_str());
            }
        }
    }
}

char* Connection::Payload::getContent() {
    return _content;
}

char* Connection::Payload::getMetadata() {
    return _metadata;
}

size_t Connection::Payload::contentSize() {
    return _len;
}

size_t Connection::Payload::metadataSize() {
    if (_metadataSizeCache != 0) {
        return _metadataSizeCache;
    }
    
    _metadataSizeCache = 1; // includes
    
    if (_includes & Includes::PayloadID) {
        _metadataSizeCache += sizeof(IDType);
    }
    
    if (_includes & Includes::CreatedAt) {
        _metadataSizeCache += sizeof(uint64_t);
    }
    
    if (_includes & Includes::TravelHistory) {
        _metadataSizeCache += sizeof(uint8_t); // nb steps
        for (Step step : _steps) {
            _metadataSizeCache += sizeof(uint8_t); // name len
            _metadataSizeCache += step.name.length(); // name
            _metadataSizeCache += sizeof(uint32_t); // diff since previous step
        }
    }
    
    return _metadataSizeCache;
}

size_t Connection::Payload::totalSize() {
    return metadataSize() + _len;
}

std::string Connection::Payload::getRawBytes() {
    return std::string(_decoded, _decodedLen);
}
