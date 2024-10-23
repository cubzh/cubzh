//
//  ThreadManager.hpp
//  xptools
//
//  Created by Gaetan de Villele on 01/02/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#pragma once

// C++
#include <thread>

namespace vx {

class ThreadManager {
    
public:
    
    static ThreadManager& shared();
    
    ~ThreadManager();
    
    /// Must be called in the thread considered to be the "main thread"
    void setMainThread();
    
    /// Returns whether it is called in the "main thread"
    bool isMainThread() const;

    /// Returns true if main thread has been set
    bool isMainThreadSet() const;

    /// Returns true if in main thread or if main thread not yet set
    bool isMainThreadOrMainThreadNotSet() const;

    /// Logs current (caller) thread
    void log(const std::string prefix) const;

private:
    
    ThreadManager();
    
    /// main thread ID
    std::thread::id _mainThreadID;
    
    /// indicates whether main thread id has been defined
    bool _mainThreadIDIsSet;
};

}
