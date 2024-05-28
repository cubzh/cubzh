//
//  log_android.cpp
//  xptools
//
//  Created by Gaetan de Villele on 04/22/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#include "vxlog.h"

// C++
#include <cstdio>

// Android
#include <android/log.h>

extern "C" {

char *_vsnprintf_helper(const char *format, ...) {
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

///
int _getAndroidLogSeverityFromVxlogSeverity(const VX_LOG_SEVERITY severity) {
    int result = ANDROID_LOG_VERBOSE;
    switch (severity)
    {
        case VX_LOG_SEVERITY_TRACE:
            // will be ANDROID_LOG_VERBOSE;
            break;
        case VX_LOG_SEVERITY_DEBUG:
            result = ANDROID_LOG_DEBUG;
            break;
        case VX_LOG_SEVERITY_INFO:
            result = ANDROID_LOG_INFO;
            break;
        case VX_LOG_SEVERITY_WARNING:
            result = ANDROID_LOG_WARN;
            break;
        case VX_LOG_SEVERITY_ERROR:
            result = ANDROID_LOG_ERROR;
            break;
        case VX_LOG_SEVERITY_FATAL:
            result = ANDROID_LOG_FATAL;
            break;
        default:
            // will be ANDROID_LOG_VERBOSE
            break;
    }
    return result;
}


int _vxlog(const int severity,
          const char *filename,
          const int line, 
          const char *str) {

    int ret;

    // Forward the '...' to vprintf
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-nonliteral"
    ret = __android_log_print(_getAndroidLogSeverityFromVxlogSeverity((VX_LOG_SEVERITY)severity),
                              "Cubzh",
                              "[%s][%d]%s", 
                              filename,
                              line,
                              str);
#pragma clang diagnostic pop

    return ret;
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
