//
//  process-ios.cpp
//  xptools-ios
//
//  Created by Gaetan de Villele on 04/07/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#include "process.hpp"

#include <mach/mach.h>

unsigned long long vx::Process::getUsedMemory() {
    struct task_basic_info info;
    mach_msg_type_number_t size = TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(),
                                   TASK_BASIC_INFO,
                                   reinterpret_cast<task_info_t>(&info),
                                   &size);
    if (kerr == KERN_SUCCESS) {
        return info.resident_size;
    } else {
        // string error: mach_error_string(kerr)
        return 0;
    }
}
