//
//  ThreadManager.cpp
//  xptools
//
//  Created by Gaetan de Villele on 01/02/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#include "ThreadManager.hpp"

// C
#include <cassert>

// xptools
#include "vxlog.h"

using namespace vx;

ThreadManager& ThreadManager::shared() {
    static ThreadManager sharedInstance;
    return sharedInstance;
}

ThreadManager::ThreadManager() :
_mainThreadID(),
_mainThreadIDIsSet(false) {}

ThreadManager::~ThreadManager() {}

void ThreadManager::setMainThread() {
    if (_mainThreadIDIsSet) {
        vxlog_warning("ThreadManager::setMainThread is called a second time. Ignoring it.");
        return;
    }
    _mainThreadID = std::this_thread::get_id();
    _mainThreadIDIsSet = true;
}

bool ThreadManager::isMainThread() const {
    assert(_mainThreadIDIsSet);
    return std::this_thread::get_id() == _mainThreadID;
}

bool ThreadManager::isMainThreadSet() const {
    return _mainThreadIDIsSet;
}

bool ThreadManager::isMainThreadOrMainThreadNotSet() const {
    return _mainThreadIDIsSet == false || std::this_thread::get_id() == _mainThreadID;
}
