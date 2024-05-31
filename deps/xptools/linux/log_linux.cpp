//
//  log_linux.hpp
//  xptools
//
//  Created by Gaëtan de Villèle on 06/16/2021.
//  Copyright © 2020 voxowl. All rights reserved.
//

// C
#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>
# include <unistd.h>
# include <sys/syscall.h>
# include <sys/stat.h>
# include <sys/types.h>
# include <sys/time.h>

// xptools
#include "vxlog.h"

extern "C" {

   char *vsnprintf_helper(const char *format, ...) {
       static char buffer[VXLOG_BUFFER_LENGTH];
       // Declare a va_list type variable
       va_list myargs;

       // Initialise the va_list variable with the ... after format
       va_start(myargs, format);
       vsnprintf(buffer, VXLOG_BUFFER_LENGTH, format, myargs);
       va_end(myargs);
       return buffer;
   }

   int _vxlog(const int severity, 
             const char *filename, 
             const int line, 
             const char *str) {

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

       pid_t processID = getpid();
       pid_t threadID = syscall(SYS_gettid);
       struct timeval tv;
       gettimeofday(&tv, NULL);
       uint64_t timestamp = tv.tv_sec * 1000 + tv.tv_usec / 1000;

       char * buffer = vsnprintf_helper("[%llu][%s][%d][%d][%s]--%s--", timestamp, sev, processID, threadID, filename, str);

       // return fprintf((severity >= LOG_SEVERITY_WARNING) ? stderr : stdout, "%s\n", buffer);
       return fprintf(stderr, "%s\n", buffer);
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
