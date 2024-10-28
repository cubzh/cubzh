//
//  OperationQueue.cpp
//  xptools
//
//  Created by Gaetan de Villele on 25/02/2020.
//

#include "OperationQueue.hpp"

#include <queue>

#ifdef __VX_SINGLE_THREAD
#define LOCK_GUARD
#define LOCK
#define UNLOCK
#else
#include <thread>
#define LOCK_GUARD const std::lock_guard<std::mutex> locker(this->_lock);
#define LOCK std::unique_lock<std::mutex> lock(_lock);
#define UNLOCK lock.unlock();
#endif

#define MAX_OPERATIONS_PER_CYCLE 10
#define SLEEP_TIME_BETWEEN_CYCLES 16 // in ms

using namespace vx;

OperationQueue *OperationQueue::getMain() {
    if (_mainQueue == nullptr) {
        _mainQueue = new OperationQueue(Type::sync);
    }
    return _mainQueue;
}

OperationQueue *OperationQueue::getServerMain() {
    if (_serverMainQueue == nullptr) {
        _serverMainQueue = new OperationQueue(Type::sync);
    }
    return _serverMainQueue;
}

OperationQueue *OperationQueue::getBackground() {
#ifdef __VX_SINGLE_THREAD
    return _mainQueue;
#else
    if (_backgroundQueue == nullptr) {
        _backgroundQueue = new OperationQueue(Type::async);
    }
    return _backgroundQueue;
#endif
}

OperationQueue *OperationQueue::getSlowBackground() {
#ifdef __VX_SINGLE_THREAD
    return _mainQueue;
#else
    if (_slowBackgroundQueue == nullptr) {
        _slowBackgroundQueue = new OperationQueue(Type::async);
    }
    return _slowBackgroundQueue;
#endif
}

OperationQueue::OperationQueue(Type type) :
_queue(),
_queueScheduled() {
    _type = type;
    _state = State::idle;
#ifndef __VX_SINGLE_THREAD
    // create a thread object that doesn't represent an execution thread
    _thread = std::thread();
#endif
}

OperationQueue::~OperationQueue() {
    
}

/// dispatch and copy
void OperationQueue::dispatch(const fp_t& op) {
    {
        LOCK_GUARD
        _queue.push_back(op);
    }
    this->startThreadIfNeeded();
}

/// dispatch and move
void OperationQueue::dispatch(fp_t&& op) {
    {
        LOCK_GUARD
        _queue.push_back(std::move(op));
    }
    this->startThreadIfNeeded();
}

/// dispatch (in front of queue) and copy
void OperationQueue::dispatchFirst(const fp_t& op) {
    {
        LOCK_GUARD
        _queue.push_front(op);
    }
    this->startThreadIfNeeded();
}

/// dispatch (in front of queue) and move
void OperationQueue::dispatchFirst(fp_t&& op) {
    {
        LOCK_GUARD
        _queue.push_front(std::move(op));
    }
    this->startThreadIfNeeded();
}

void OperationQueue::schedule(const fp_t& op, uint64_t ms) {
    {
        LOCK_GUARD
        using namespace std::chrono;
        system_clock::time_point tp = system_clock::now() + milliseconds(ms);
        time_t t = system_clock::to_time_t(tp);
        _queueScheduled[t] = op;
    }
    this->startThreadIfNeeded();
}

void OperationQueue::schedule(const fp_t&& op, uint64_t ms) {
    {
        LOCK_GUARD
        using namespace std::chrono;
        uint64_t now = duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
        uint64_t date = now + ms;
        _queueScheduled[date] = std::move(op);
    }
    this->startThreadIfNeeded();
}

void OperationQueue::callFirstDispatchedBlocks(size_t n) {
    bool skipScheduled = false;
    while (n > 0) {
        LOCK

        if (skipScheduled == false && _queueScheduled.empty() == false) {
            using namespace std::chrono;
            uint64_t now = duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
            
            std::pair<uint64_t,fp_t> entry = *(_queueScheduled.begin());
            if (entry.first <= now) {
                fp_t op = entry.second;
                _queueScheduled.erase(_queueScheduled.begin());
                // unlock before calling op()
                // because op() could need to add something in the queue
                UNLOCK
                op();
                
                --n;
                continue;
            } else {
                skipScheduled = true; // other scheduled ops are for a later time
            }
        }
        
        if (_queue.empty()) {
            UNLOCK
            break;
        } else {
            fp_t op = std::move(_queue.front());
            _queue.pop_front();
            // unlock before calling op()
            // because op() could need to add something in the queue
            UNLOCK
            op();
        }
        
        --n;
    }
}

// MARK: - private -

///
OperationQueue *OperationQueue::_mainQueue = nullptr;

///
OperationQueue *OperationQueue::_serverMainQueue = nullptr;

///
OperationQueue *OperationQueue::_backgroundQueue = nullptr;

///
OperationQueue *OperationQueue::_slowBackgroundQueue = nullptr;

///
void OperationQueue::startThreadIfNeeded() {
#ifdef __VX_SINGLE_THREAD
    return;
#else
    if (_type != Type::async) {
        return; // only async operation queues can have a thread
    }
    LOCK_GUARD
    if (_state != State::runningInBackground) {
        _state = State::runningInBackground;
        if (_thread.joinable()) {
            _thread.join();
        }
        _thread = std::thread(&OperationQueue::threadFunction, this);
    } // else thread is already running
#endif
}

#ifndef __VX_SINGLE_THREAD
void OperationQueue::threadFunction() {
    std::unique_lock<std::mutex> locker(_lock, std::defer_lock);
    uint64_t now;
    std::queue<fp_t> operations;
    std::map<uint64_t,fp_t>::iterator itScheduled;
    std::pair<uint64_t,fp_t> opScheduled;
    fp_t op;
    int n;

    while (true) {
        n = 0;
        locker.lock();

        if (_queue.empty() && _queueScheduled.empty()) {
            _state = State::idle;
            locker.unlock();
            break;
        }

        if (_queueScheduled.empty() == false) {
            // TODO: _queueScheduled -> std::list<std::pair<uint64_t,fp_t>>
            now = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
            itScheduled = _queueScheduled.begin();

            opScheduled = *(itScheduled);

            if (opScheduled.first <= now) {
                operations.push(opScheduled.second);
                ++n;
                _queueScheduled.erase(itScheduled);
            }
        }
        
        while (_queue.empty() == false && n < MAX_OPERATIONS_PER_CYCLE) {
            operations.push(_queue.front());
            ++n;
            _queue.pop_front();
        }

        locker.unlock();

        while (operations.empty() == false) {
            op = operations.front();
            operations.pop();
            op();
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(SLEEP_TIME_BETWEEN_CYCLES));
    }
}
#endif
