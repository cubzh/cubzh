//
//  time.cpp
//  xptools
//
//  Created by Adrien Duermael on 16/11/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#include "vxtime.h"

#include <stdio.h>
//#include <time.h>
#include <sys/time.h>

#define STR_BUFF_SIZE 50
#define STR_BUFF2_SIZE (STR_BUFF_SIZE+5)

/*
 Windows:
 #include "windows.h"
 SYSTEMTIME time;
 GetSystemTime(&time);
 WORD millis = (time.wSeconds * 1000) + time.wMilliseconds;
 */

const char* vx::time_::nowStr(const char *format, bool appendMilliseconds) {
    
    static timeval tv;
    static int millis;
    
    static char buff[STR_BUFF_SIZE];
    static char buff2[STR_BUFF2_SIZE]; // used when appending milliseconds
    // static struct tm *sTm;
    //    static time_t now;
    
    
    if (format == nullptr) {
        format = "%Y-%m-%d %H:%M:%S";
    }
    
//    time(&now);
//    sTm = gmtime(&now);
    
    gettimeofday(&tv, nullptr);
    
    // long millis = (time.tv_sec * 1000) + (time.tv_usec / 1000);
    // size_t crop = strftime (buff, STR_BUFF_SIZE, format, sTm);
    
    size_t crop = strftime (buff, STR_BUFF_SIZE, format, localtime(&tv.tv_sec));
    if (crop != 0) {
        buff[crop] = '\0';
    }
    
    if (appendMilliseconds) {
        millis = tv.tv_usec / 1000;
        snprintf(buff2, STR_BUFF2_SIZE, "%s:%03d", buff, millis);
        return buff2;
    }
    
    return buff;
}

const char* vx::time_::nowStrHMS() {
    return nowStr("%H:%M:%S", false);
}

const char* vx::time_::nowStrYmdHMS() {
    return nowStr("%Y-%m-%d %H:%M:%S", false);
}

/// --------------------------------------------------
///
/// C-style functions
///
/// --------------------------------------------------

extern "C" {

const char* nowStr(const char *format, bool appendMilliseconds) {
    return vx::time_::nowStr(format, appendMilliseconds);
}

const char* nowStrHMS() {
    return vx::time_::nowStrHMS();
}

const char* nowStrYmdHMS() {
    return vx::time_::nowStrYmdHMS();
}

}
