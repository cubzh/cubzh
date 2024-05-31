//
//  web-macos.mm
//  xptools
//
//  Created by Adrien Duermael on 29/10/2021.
//  Copyright © 2021 voxowl. All rights reserved.
//

#include "web.hpp"

// Obj-C
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

void vx::Web::openModal(const std::string &url) {
    // there's no modal system on macOS
    open(url);
}

void vx::Web::open(const std::string &url) {
    NSString *urlString = [NSString stringWithUTF8String:url.c_str()];
    NSURL *nsurl = [NSURL URLWithString:urlString];
    if (nsurl != nil) {
        [[NSWorkspace sharedWorkspace] openURL:nsurl];
    }
}
