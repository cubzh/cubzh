//
//  strings.h
//  xptools
//
//  Created by Adrien Duermael on 5/13/20.
//  Copyright © 2020 voxowl. All rights reserved.
//

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

///
int c_char32fromUTF8(unsigned int *out_char, const char *in_text, const char *in_text_end);

#ifdef __cplusplus
} // extern "C"
#endif
