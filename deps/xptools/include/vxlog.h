//
//  vxlog.h
//  xptools
//
//  Created by Gaetan de Villele on 19/04/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>

#define VXLOG_BUFFER_LENGTH 2048

//#ifdef DEBUG
#define VXLOG_EASY_TO_READ
//#endif

#ifndef __FILE_NAME__
#ifdef __VX_PLATFORM_WINDOWS
#include <string.h>
#define __FILE_NAME__ (strrchr(__FILE__, '\\') ? strrchr(__FILE__, '\\') + 1 : __FILE__)
#endif // __VX_PLATFORM_WINDOWS

#ifdef __VX_PLATFORM_LINUX // Linux but NOT Android
#include <string.h>
#define __FILE_NAME__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)
//#endif
#endif // __VX_PLATFORM_LINUX
#endif

typedef enum {
    VX_LOG_SEVERITY_TRACE,
    VX_LOG_SEVERITY_DEBUG,
    VX_LOG_SEVERITY_INFO,
    VX_LOG_SEVERITY_WARNING,
    VX_LOG_SEVERITY_ERROR,
    VX_LOG_SEVERITY_FATAL
} VX_LOG_SEVERITY;

int vxlog(const int severity,
          const char *filename,
          const int line,
          const char *format,
          ...);

int vxlog_with_va_list(const int severity,
                       const char *filename,
                       const int line,
                       const char *format,
                       va_list args);

#define vxlog_trace(...) vxlog(VX_LOG_SEVERITY_TRACE, __FILE_NAME__, __LINE__, __VA_ARGS__)
#define vxlog_debug(...) vxlog(VX_LOG_SEVERITY_DEBUG, __FILE_NAME__, __LINE__, __VA_ARGS__)
#define vxlog_info(...) vxlog(VX_LOG_SEVERITY_INFO, __FILE_NAME__, __LINE__, __VA_ARGS__)
#define vxlog_warning(...) vxlog(VX_LOG_SEVERITY_WARNING, __FILE_NAME__, __LINE__, __VA_ARGS__)
#define vxlog_error(...) vxlog(VX_LOG_SEVERITY_ERROR, __FILE_NAME__, __LINE__, __VA_ARGS__)
#define vxlog_fatal(...) vxlog(VX_LOG_SEVERITY_FATAL, __FILE_NAME__, __LINE__, __VA_ARGS__)

#ifdef __cplusplus
} // extern "C"
#endif
