//
//  web-ios.mm
//  xptools
//
//  Created by Adrien Duermael on 29/10/2021.
//  Copyright © 2021 voxowl. All rights reserved.
//

#include "web.hpp"

// Obj-C
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <UIKit/UIKit.h>

void vx::Web::openModal(const std::string &url) {
    
    // Displaying a very simple web view.
    // It would be nice to add controls (next/previous page, loading indicator...)
    // This requires designing our own UIView embedding the WKWebView.
    
    NSString *urlString = [NSString stringWithUTF8String:url.c_str()];
    NSURL *nsurl = [NSURL URLWithString:urlString];
    
    if (nsurl != nil) {
        NSURLRequest *req = [NSURLRequest requestWithURL:nsurl];
        WKWebView *wv = [WKWebView new];
        [wv loadRequest:req];
        
        UIViewController *wvc = [UIViewController new];
        wvc.view = wv;
        
        UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
        [vc presentViewController:wvc animated:YES completion:nil];
    }
}

void vx::Web::open(const std::string &url) {
    NSString *urlString = [NSString stringWithUTF8String:url.c_str()];
    NSURL *nsurl = [NSURL URLWithString:urlString];
    
    if (nsurl != nil) {
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(openURL:options:completionHandler:)]) {
            [[UIApplication sharedApplication] openURL:nsurl options:@{} completionHandler:nullptr];
        } else {
            // Fallback on earlier versions
            [[UIApplication sharedApplication] openURL:nsurl];
        }
    }
}
