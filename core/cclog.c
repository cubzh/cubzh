// -------------------------------------------------------------
//  Cubzh Core
//  log.c
//  Created by Adrien Duermael on July 18, 2022.
// -------------------------------------------------------------

#include "cclog.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>

const char *_cclog_filename(const char *file) {
    const char *p = strrchr(file, '/');
    if (p == NULL)
        p = strrchr(file, '\\');
    return p ? p + 1 : file;
}

char *_cc_vsnprintf_helper(const char *format, ...) {
    static char buffer[LOG_BUFFER_LENGTH];
    // Declare a va_list type variable
    va_list myargs;

    // Initialise the va_list variable with the ... after format
    va_start(myargs, format);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-nonliteral"
    vsnprintf(buffer, LOG_BUFFER_LENGTH, format, myargs);
#pragma clang diagnostic pop
    va_end(myargs);
    return buffer;
}

int _cclog(const int severity,
           const char *filename,
           const int line,
           const char *format,
           va_list args) {

    // create a static memory buffer
    static char bufferPreString[LOG_BUFFER_LENGTH];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-nonliteral"
    vsnprintf(bufferPreString, LOG_BUFFER_LENGTH, format, args);
#pragma clang diagnostic pop

    const char *sev;

    switch (severity) {
        case LOG_SEVERITY_TRACE:
            sev = "TRACE";
            break;
        case LOG_SEVERITY_DEBUG:
            sev = "DEBUG";
            break;
        case LOG_SEVERITY_INFO:
            sev = "INFO";
            break;
        case LOG_SEVERITY_WARNING:
            sev = "WARNING";
            break;
        case LOG_SEVERITY_ERROR:
            sev = "ERROR";
            break;
        case LOG_SEVERITY_FATAL:
            sev = "FATAL";
            break;
        default:
            sev = "";
            break;
    }

    char *buffer = _cc_vsnprintf_helper("%s %s", sev, bufferPreString);

    return fprintf((severity >= LOG_SEVERITY_WARNING) ? stderr : stdout, "%s\n", buffer);
}

log_func_ptr cclog_function_ptr = _cclog;

int cclog(const int severity, const char *filename, const int line, const char *format, ...) {
    int r = -1;
    if (cclog_function_ptr != NULL) {
        va_list myargs;
        va_start(myargs, format);
        r = cclog_function_ptr(severity, filename, line, format, myargs);
        va_end(myargs);
    }
    return r;
}
