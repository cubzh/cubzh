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

@interface NetworkManager : NSObject <NSURLSessionDataDelegate>
@property (nonatomic, strong, readonly) NSURLSession *session;
+ (instancetype)sharedManager;
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request forHttpRequest:(vx::HttpRequest_SharedPtr*)httpReqPtr;
@end

@implementation NetworkManager {
    NSMutableDictionary<NSNumber *, NSValue *> *_taskMap;
}

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
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        _taskMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request forHttpRequest:(vx::HttpRequest_SharedPtr*)httpReqPtr {
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request];
    @synchronized (_taskMap) {
        _taskMap[@(task.taskIdentifier)] = [NSValue valueWithPointer: httpReqPtr];
    }
    return task;
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    @synchronized (_taskMap) {
        NSValue* dictValue = _taskMap[@(dataTask.taskIdentifier)];
        vx::HttpRequest_SharedPtr* httpReqPtr = static_cast<vx::HttpRequest_SharedPtr*>([dictValue pointerValue]);
        if (httpReqPtr) {
//            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
//            
//            // Set response status code
//            httpReq->getResponse().setStatusCode(httpResponse.statusCode);
//            
//            // Set response headers
//            NSDictionary *headers = httpResponse.allHeaderFields;
//            std::unordered_map<std::string, std::string> responseHeaders;
//            for (NSString *key in headers) {
//                NSString *value = headers[key];
//                responseHeaders[[key lowercaseString].UTF8String] = value.UTF8String;
//            }
//            httpReq->getResponse().setHeaders(responseHeaders);
//            
//            // Initialize response body
//            httpReq->getResponse().setBytes("");
//            httpReq->getResponse().setSuccess(true);
//            
//            // Call callback for the first time with headers
//            httpReq->callCallback();
        }
    }
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    @synchronized (_taskMap) {
        NSValue* dictValue = _taskMap[@(dataTask.taskIdentifier)];
        vx::HttpRequest_SharedPtr* httpReqPtr = static_cast<vx::HttpRequest_SharedPtr*>([dictValue pointerValue]);
        if (httpReqPtr) {
//            // Append new data to existing response
//            std::string newBytes(reinterpret_cast<const char*>(data.bytes), data.length);
//            std::string currentBytes = httpReq->getResponse().getBytes();
//            currentBytes.append(newBytes);
//            httpReq->getResponse().setBytes(currentBytes);
//            
//            // Call callback with the updated data
//            httpReq->callCallback();
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    @synchronized (_taskMap) {
        NSValue* dictValue = _taskMap[@(dataTask.taskIdentifier)];
        vx::HttpRequest_SharedPtr* httpReqPtr = static_cast<vx::HttpRequest_SharedPtr*>([dictValue pointerValue]);
        if (httpReqPtr) {
            if (error) {
                vxlog_error("HTTP request failed: %s", error.localizedDescription.UTF8String);
                httpReq->getResponse().setSuccess(false);
                httpReq->setStatus(vx::HttpRequest::Status::FAILED);
            } else {
                httpReq->setStatus(vx::HttpRequest::Status::DONE);
            }
            
            // Final callback
            httpReq->callCallback();
            
            // Clean up
            httpReq->_detachPlatformObject();
            [_taskMap removeObjectForKey:@(task.taskIdentifier)];
        }
    }
}

@end

namespace vx {

void HttpRequest::_sendAsync() {

    HttpRequest_SharedPtr httpReq = this->_weakSelf.lock();
    if (httpReq == nullptr) {
        return;
    }
    HttpRequest_SharedPtr *httpReqPtr = new HttpRequest_SharedPtr(httpReq);

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

        // Create task with the NetworkManager
        NSURLSessionDataTask *task = [[NetworkManager sharedManager] dataTaskWithRequest:request forHttpRequest:httpReqPtr];

        httpReq->_attachPlatformObject((__bridge_retained void*)task);
        httpReq->setStatus(HttpRequest::Status::PROCESSING);

        [task resume];
    }
}

void HttpRequest::_cancel() {
    HttpRequest_SharedPtr httpReq = this->_weakSelf.lock();
    if (httpReq == nullptr) {
        return;
    }

    if (httpReq->_platformObject == nullptr) {
        return;
    }
    [(__bridge NSURLSessionDataTask*)httpReq->_platformObject cancel];
    httpReq->_detachPlatformObject();
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
