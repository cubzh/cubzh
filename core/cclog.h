// -------------------------------------------------------------
//  Cubzh Core
//  cclog.h
//  Created by Adrien Duermael on July 18, 2022.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>

// NOTE: the log function is implemented here
// with an option to be replaced by external implementation.
// This is temporary. We had to do this for the engine to
// be built without Cubzh CPF (Cross Platform Framework).
// Among other things, Cubzh CPF implements a cross-platform
// version of the log function.
// cclog files will go away once Cubzh CPF can be open sourced
// and used as a dependency.

typedef int (*log_func_ptr)(const int severity,
                            const char *filename,
                            const int line,
                            const char *format,
                            va_list args);

extern log_func_ptr cclog_function_ptr;

#define LOG_BUFFER_LENGTH 2048

const char *_cclog_filename(const char *file);

#ifndef __FILE_NAME__
#define __FILE_NAME__ _cclog_filename(__FILE__)
#endif

typedef enum {
    LOG_SEVERITY_TRACE = 0,
    LOG_SEVERITY_DEBUG = 1,
    LOG_SEVERITY_INFO = 2,
    LOG_SEVERITY_WARNING = 3,
    LOG_SEVERITY_ERROR = 4,
    LOG_SEVERITY_FATAL = 5
} LOG_SEVERITY;

int cclog(const int severity, const char *filename, const int line, const char *format, ...);

#define cclog_trace(...) cclog(LOG_SEVERITY_TRACE, NULL, 0, __VA_ARGS__)
#define cclog_debug(...) cclog(LOG_SEVERITY_DEBUG, __FILE_NAME__, __LINE__, __VA_ARGS__)
#define cclog_info(...) cclog(LOG_SEVERITY_INFO, __FILE_NAME__, __LINE__, __VA_ARGS__)
#define cclog_warning(...) cclog(LOG_SEVERITY_WARNING, __FILE_NAME__, __LINE__, __VA_ARGS__)
#define cclog_error(...) cclog(LOG_SEVERITY_ERROR, __FILE_NAME__, __LINE__, __VA_ARGS__)
#define cclog_fatal(...) cclog(LOG_SEVERITY_FATAL, __FILE_NAME__, __LINE__, __VA_ARGS__)

#ifdef __cplusplus
} // extern "C"
#endif
