//
//  log.mm
//  xptools
//
//  Created by Gaetan de Villele on 19/04/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#include "vxlog.h"

// C
#include <stdio.h>
#include <stdarg.h>

#import "Foundation/Foundation.h"
#include <unistd.h>
#include <sys/syscall.h>
#include <sys/time.h>

#include <string>

extern "C" {

char *vsnprintf_helper(const char *format, ...) {
    static char buffer[VXLOG_BUFFER_LENGTH];
    // Declare a va_list type variable
    va_list myargs;

    // Initialise the va_list variable with the ... after format
    va_start(myargs, format);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-nonliteral"
    vsnprintf(buffer, VXLOG_BUFFER_LENGTH, format, myargs);
#pragma clang diagnostic pop

    va_end(myargs);
    return buffer;
}

int _vxlog(const int severity, const char *filename, const int line, const char *str) {
    
    const char *sev = "";
    
#ifdef VXLOG_EASY_TO_READ
    switch (severity)
    {
        case VX_LOG_SEVERITY_TRACE:
            sev = "";
            break;
        case VX_LOG_SEVERITY_DEBUG:
            sev = "🤓 ";
            break;
        case VX_LOG_SEVERITY_INFO:
            sev = "";
            break;
        case VX_LOG_SEVERITY_WARNING:
            sev = "⚠️ ";
            break;
        case VX_LOG_SEVERITY_ERROR:
            sev = "❌ ";
            break;
        case VX_LOG_SEVERITY_FATAL:
            sev = "🔥 ";
            break;
    }
#else
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
    }
#endif

#ifdef VXLOG_EASY_TO_READ
    char *buffer = vsnprintf_helper("%s%s",
                                    sev,
                                    str);
    
    return fprintf((severity >= VX_LOG_SEVERITY_WARNING) ? stderr : stdout, "%s\n", buffer);
#else
    pid_t processID = getpid();
    struct timeval tv;
    gettimeofday(&tv, nullptr);

    const uint64_t threadID = (uint64_t)([NSThread currentThread]);
    const uint64_t timestamp = tv.tv_sec * 1000 + tv.tv_usec / 1000;
    // print inside memory buffer Va_ag
    
    char *buffer = nullptr;
    
    if (filename == nullptr) {
        buffer = vsnprintf_helper("[%llu][%s][%d][%llu]--%s--",
                                  timestamp,
                                  sev,
                                  processID,
                                  threadID,
                                  bufferPreString);
    } else {
        buffer = vsnprintf_helper("[%llu][%s][%d][%llu][%s][%d]--%s--",
                                  timestamp,
                                  sev,
                                  processID,
                                  threadID,
                                  filename,
                                  line,
                                  bufferPreString);
    }
    
    return fprintf((severity >= VX_LOG_SEVERITY_WARNING) ? stderr : stdout, "%s\n", buffer);
#endif
}

int vxlog(const int severity, const char *filename, const int line, const char *format, ...) {

    static char bufferPreString[VXLOG_BUFFER_LENGTH];

    va_list myargs;
    va_start(myargs, format);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-nonliteral"
    vsnprintf(bufferPreString, VXLOG_BUFFER_LENGTH, format, myargs);
#pragma clang diagnostic pop
    va_end(myargs);

    return _vxlog(severity, filename, line, bufferPreString);
}

int vxlog_with_va_list(const int severity,
                       const char *filename,
                       const int line,
                       const char *format,
                       va_list args) {
    
    static char bufferPreString[VXLOG_BUFFER_LENGTH];
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-nonliteral"
    vsnprintf(bufferPreString, VXLOG_BUFFER_LENGTH, format, args);
#pragma clang diagnostic pop
    
    return _vxlog(severity, filename, line, bufferPreString);
}

}
