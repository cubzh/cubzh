
#include "vxlog.h"

// C++
#include <cstdio>
#include <cstdarg>

extern "C" {

const char* _getPrefixFromVxlogSeverity(const VX_LOG_SEVERITY severity) {
    switch (severity) {
        case VX_LOG_SEVERITY_TRACE: return "TRACE";
        case VX_LOG_SEVERITY_DEBUG: return "DEBUG";
        case VX_LOG_SEVERITY_INFO: return "INFO";
        case VX_LOG_SEVERITY_WARNING: return "WARN";
        case VX_LOG_SEVERITY_ERROR: return "ERROR";
        case VX_LOG_SEVERITY_FATAL: return "FATAL";
        default: return "";
    }
}

int _vxlog(const int severity, 
          const char *filename,
          const int line, 
          const char *str) {

    int ret;

    // Printfs are forwarded by Emscripten to the console
    printf("Particubes [%s][%s][%d] %s\n",
        _getPrefixFromVxlogSeverity((VX_LOG_SEVERITY)severity), 
        filename,
        line,
        str);

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
