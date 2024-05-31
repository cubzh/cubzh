//
//  time.h
//  xptools
//
//  Created by Adrien Duermael on 16/11/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#pragma once

#ifdef __cplusplus

namespace vx {
namespace time_ {

// the string returned will be invalid
// after another call to vx:_time::now<something> is made
const char* nowStr(const char *format, bool appendMilliseconds);
const char* nowStrHMS();
const char* nowStrYmdHMS();

}
}

extern "C" {
#endif

const char* nowStr(const char *format, bool appendMilliseconds);
const char* nowStrHMS(void);
const char* nowStrYmdHMS(void);

#ifdef __cplusplus
} // extern "C"
#endif
