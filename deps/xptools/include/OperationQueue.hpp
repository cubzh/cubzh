//
//  OperationQueue.hpp
//  xptools
//
//  Created by Gaetan de Villele on 25/02/2020.
//

#pragma once

// C++
#include <future>
#include <queue>
#include <map>
#include <chrono>

// xptools
#include "Macros.h"

namespace vx {

///
class OperationQueue final {
      
public:
    
    /// Types of operation queues
    enum class Type {
        sync,
        async
    };
    
    ///
    enum class State {
        idle,
        runningInBackground
    };

    ///
    typedef std::function<void(void)> fp_t;
    
    ///
    static OperationQueue *getMain();
    
    ///
    static OperationQueue *getServerMain();
    
    ///
    static OperationQueue *getBackground();

    ///
    static OperationQueue *getSlowBackground();
    
    /// Destructor
    virtual ~OperationQueue();
    
    /// dispatch and copy
    void dispatch(const fp_t& op);
    
    /// dispatch and move
    void dispatch(fp_t&& op);
    
    /// dispatch and copy, to be triggered in `ms` milliseconds
    void schedule(const fp_t& op, uint64_t ms);
    
    /// dispatch and move, to be triggered in `ms` milliseconds
    void schedule(const fp_t&& op, uint64_t ms);
    
    /// dispatch (in front of queue) and copy
    void dispatchFirst(const fp_t& op);
    
    /// dispatch (in front of queue) and move
    void dispatchFirst(fp_t&& op);
    
    /// Calls n first blocks to dispatch
    void callFirstDispatchedBlocks(size_t n);
    
            
protected:
    
    VX_DISALLOW_COPY_AND_ASSIGN(OperationQueue)

    
private:
    
    ///
    static OperationQueue *_mainQueue;
    
    ///
    static OperationQueue *_serverMainQueue;
    
    ///
    static OperationQueue *_backgroundQueue;

    ///
    static OperationQueue *_slowBackgroundQueue;

    /// Constructor
    OperationQueue(Type type);
    
    /// tasks queue
    std::deque<fp_t> _queue;
    
    /// scheduled tasks queue
    std::map<uint64_t,fp_t> _queueScheduled;
    
    /// queue type
    Type _type;
    
    /// Indicates the current state of the queue.
    /// This is used for managing the background thread
    /// of certain queues.
    State _state;

    void startThreadIfNeeded();
#ifndef __VX_SINGLE_THREAD
    std::mutex _lock;
    std::thread _thread;

    void threadFunction();
#endif
};

}
