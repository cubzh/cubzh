//
//  log_windows.hpp
//  xptools
//
//  Created by Gaëtan de Villèle on 06/16/2021.
//  Copyright © 2020 voxowl. All rights reserved.
//

// C 
#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>
# include <Windows.h>
# include <sysinfoapi.h>
# include <time.h>

// xptools
#include "vxlog.h"

extern "C" {

#define VXLOG_BUFFER_LENGTH 2048

uint64_t GetSystemTimeAsUnixTime()
{
    struct timeval* tp;
    struct timezone* tzp;
    const uint64_t EPOCH = (uint64_t)116444736000000000ULL;

    SYSTEMTIME  system_time;
    FILETIME    file_time;
    uint64_t    time;

    GetSystemTime(&system_time);
    SystemTimeToFileTime(&system_time, &file_time);
    time = ((uint64_t)file_time.dwLowDateTime);
    time += ((uint64_t)file_time.dwHighDateTime) << 32;

    return (uint64_t)((time - EPOCH) / 10000L + system_time.wMilliseconds);
}

   char *vsnprintf_helper(const char *format, ...) {
       static char buffer[VXLOG_BUFFER_LENGTH];
       // Declare a va_list type variable
       va_list myargs;

       // Initialise the va_list variable with the ... after format
       va_start(myargs, format);
       vsnprintf_s(buffer, VXLOG_BUFFER_LENGTH, _TRUNCATE, format, myargs);
       va_end(myargs);
       return buffer;
   }

   // prints in the Visual Studio debug console
   int _vxlog(const int severity, const char *filename, const int line, const char *str) {

       const char *sev;

       switch (severity)
       {
       case VX_LOG_SEVERITY_TRACE:
           sev = "TRACE";
           break;
       case VX_LOG_SEVERITY_DEBUG:
           sev = "DEBUG";
           break;
       case VX_LOG_SEVERITY_INFO:
           sev = "INFO";
           break;
       case VX_LOG_SEVERITY_WARNING:
           sev = "WARNING";
           break;
       case VX_LOG_SEVERITY_ERROR:
           sev = "ERROR";
           break;
       case VX_LOG_SEVERITY_FATAL:
           sev = "FATAL";
           break;
       default:
           sev = "WRONGTRACE";
           break;
       }

       DWORD processID = GetCurrentProcessId();
       DWORD threadID = GetCurrentThreadId();
       uint64_t timestamp = GetSystemTimeAsUnixTime();

       // print inside memory buffer Va_ag
#ifdef VXLOG_EASY_TO_READ
       char* buffer = vsnprintf_helper("[%s]%s", sev, str);
#else
       char* buffer = vsnprintf_helper("[%llu][%d][%d][%s][%d][%s]--%s--", timestamp, processID, threadID, filename, line, sev, str);
#endif

// #ifdef DEBUG
       // Send Memory buffer to STDout vsConsole
       OutputDebugStringA(buffer);
       OutputDebugStringA("\n");
// #endif

       // Send log to stdout
       printf("%s\n", buffer);

       return 1;
   }

   int vxlog(const int severity, const char *filename, const int line, const char *format, ...) {

        static char bufferPreString[VXLOG_BUFFER_LENGTH];

        va_list myargs;
        va_start(myargs, format);
        vsnprintf(bufferPreString, VXLOG_BUFFER_LENGTH, format, myargs);
        va_end(myargs);

        return _vxlog(severity, filename, line, bufferPreString);
    }

    int vxlog_with_va_list(const int severity,
                           const char *filename,
                           const int line,
                           const char *format,
                           va_list args) {
        
        static char bufferPreString[VXLOG_BUFFER_LENGTH];
        
        vsnprintf(bufferPreString, VXLOG_BUFFER_LENGTH, format, args);
        
        return _vxlog(severity, filename, line, bufferPreString);
    }

}
