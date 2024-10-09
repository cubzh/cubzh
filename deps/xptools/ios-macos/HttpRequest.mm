//
//  HttpRequest.mm
//  xptools
//
//  Created by Adrien Duermael on 09/27/2024.
//  Copyright © 2024 voxowl. All rights reserved.
//

#include "HttpRequest.hpp"

// Obj-C
#import <Foundation/Foundation.h>

// xptools
#include "vxlog.h"

@interface NetworkManager : NSObject
@property (nonatomic, strong, readonly) NSURLSession *session;
+ (instancetype)sharedManager;
@end

@implementation NetworkManager
@synthesize session = _session;
+ (instancetype)sharedManager {
    static NetworkManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}
- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.HTTPShouldSetCookies = NO;
        _session = [NSURLSession sessionWithConfiguration:configuration];
    }
    return self;
}
@end

namespace vx {

void HttpRequest::_sendAsync(HttpRequest_SharedPtr httpReq) {
    @autoreleasepool {
        NSString *urlString = [NSString stringWithUTF8String:httpReq->constructURLString().c_str()];
        NSURL *url = [NSURL URLWithString:urlString];

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        NSString *httpMethod = [NSString stringWithUTF8String:httpReq->getMethod().c_str()];
        if (httpMethod) {
            [request setHTTPMethod:httpMethod];
        } else {
            vxlog_error("Failed to create NSString from HTTP method");
            httpReq->setStatus(HttpRequest::Status::FAILED);
            return;
        }

        // Set headers
        for (const auto &header : httpReq->getHeaders()) {
            NSString *key = [NSString stringWithUTF8String:header.first.c_str()];
            NSString *value = [NSString stringWithUTF8String:header.second.c_str()];
            [request setValue:value forHTTPHeaderField:key];
        }

        // Set body for POST requests
        if (httpReq->getMethod() == "POST" || httpReq->getMethod() == "PATCH") {
            NSData *bodyData = [NSData dataWithBytes:httpReq->getBodyBytes().data()
                                              length:httpReq->getBodyBytes().size()];
            [request setHTTPBody:bodyData];
        }

        // DO NOT USE DEFAULT COOKIE STORE
        // NSURLSession *session = [NSURLSession sharedSession];
        NSURLSession *session = [NetworkManager sharedManager].session;

        NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                vxlog_error("HTTP request failed: %s", error.localizedDescription.UTF8String);
                httpReq->setStatus(HttpRequest::Status::FAILED);
            } else {
                httpReq->_detachPlatformObject();
                if (httpReq->getStatus() != HttpRequest::Status::PROCESSING) {
                    return;
                }
                NSHTTPURLResponse *httpResponse = static_cast<NSHTTPURLResponse *>(response);

                // Set response status code
                httpReq->getResponse().setStatusCode(httpResponse.statusCode);

                // Set response headers
                NSDictionary *headers = httpResponse.allHeaderFields;
                std::unordered_map<std::string, std::string> responseHeaders;
                for (NSString *key in headers) {
                    NSString *value = headers[key];
                    responseHeaders[[key lowercaseString].UTF8String] = value.UTF8String;
                }
                httpReq->getResponse().setHeaders(responseHeaders);

                // Set response body
                std::string bodyBytes(reinterpret_cast<const char*>(data.bytes), data.length);
                httpReq->getResponse().setBytes(bodyBytes);

                httpReq->getResponse().setSuccess(true);
                httpReq->setStatus(HttpRequest::Status::DONE);
            }

            httpReq->callCallback();
        }];

        httpReq->_attachPlatformObject((__bridge_retained void*)task);
        httpReq->setStatus(HttpRequest::Status::PROCESSING);

        [task resume];
    }
}

void HttpRequest::_cancel(HttpRequest_SharedPtr httpReq) {
    if (_platformObject == nullptr) {
        return;
    }
    [(__bridge NSURLSessionDataTask*)_platformObject cancel];
    _detachPlatformObject();
}

void HttpRequest::_attachPlatformObject(void *o) {
    if (_platformObject != nullptr) {
        _detachPlatformObject();
    }
    _platformObject = o;
}

void HttpRequest::_detachPlatformObject() {
    if (_platformObject == nullptr) {
        return;
    }
    CFRelease(_platformObject);
    _platformObject = nullptr;
}

}
