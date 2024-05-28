
#include "process.hpp"

#pragma comment(linker, "/DEFAULTLIB:psapi.lib")

// windows
#include <windows.h>
#include "psapi.h"

unsigned long long vx::Process::getUsedMemory() {
    PROCESS_MEMORY_COUNTERS_EX pmc;
    GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS *)&pmc, sizeof(pmc));
    SIZE_T virtualMemUsedByProcess = pmc.QuotaPagedPoolUsage; // QuotaPagedPoolUsage gives exactly what the app needs
    return virtualMemUsedByProcess;
}

unsigned int vx::Process::getUsedMemoryMB() {
    // TODO: implement me!
    return 0;
}

void vx::Process::setMemoryUsageLimitMB(unsigned int i) {
    // TODO: implement me!
}

unsigned int vx::Process::getMemoryUsageLimitMB(void) {
    // TODO: implement me!
    return 999;
}
