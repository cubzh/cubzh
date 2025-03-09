//
//  process.cpp
//  xptools
//
//  Created by Adrien Duermael on August 19, 2022
//  Copyright © 2022 voxowl. All rights reserved.
//

#include "process.hpp"

unsigned int vx::Process::_memoryUsageLimitMB = 0;

void vx::Process::setMemoryUsageLimitMB(unsigned int i) {
    _memoryUsageLimitMB = i;
}

unsigned int vx::Process::getMemoryUsageLimitMB(void) {
    return _memoryUsageLimitMB;
}

unsigned int vx::Process::getUsedMemoryMB() {
    return static_cast<unsigned int>(getUsedMemory() >> 20);
}
