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
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(),
                                   TASK_VM_INFO,
                                   reinterpret_cast<task_info_t>(&vmInfo),
                                   &count);
    if (kerr == KERN_SUCCESS) {
        return vmInfo.phys_footprint;
    } else {
        // string error: mach_error_string(kerr)
        return 0;
    }
}
