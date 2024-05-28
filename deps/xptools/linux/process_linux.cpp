//
//  process_linux.cpp
//  linux
//
//  Created by Corentin Cailleaud on 04/07/2022.
//  Copyright © 2022 voxowl. All rights reserved.
//

#include "process.hpp"

#include <cstdio>
#include <unistd.h>

unsigned long long vx::Process::getUsedMemory() {
    // taken from https://stackoverflow.com/a/14927379
    long rss = 0L;
    FILE* f = fopen( "/proc/self/statm", "r");
    if (f == NULL ) {
        return 0; // can't open
    }

    if (fscanf(f, "%*s%ld", &rss ) != 1) {
        fclose(f);
        return 0; // can't read
    }

    fclose(f);
    return static_cast<unsigned long long>(rss) * static_cast<unsigned long long>(sysconf(_SC_PAGESIZE));
}
