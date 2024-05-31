//
//  process.hpp
//  xptools
//
//  Created by Corentin Cailleaud on 01/07/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#pragma once

// C++
#include <string>

namespace vx {

class Process final {
  public:
    // Get the amount of currently used memory by this process in bytes.
    static unsigned long long getUsedMemory();
    
    // Get the amount of currently used memory by this process in megabytes.
    static unsigned int getUsedMemoryMB();
    
    //
    static void setMemoryUsageLimitMB(unsigned int i);
    
    //
    static unsigned int getMemoryUsageLimitMB(void);
    
private:
    static unsigned int _memoryUsageLimitMB;
};
}
