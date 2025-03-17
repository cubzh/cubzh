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

// Create a dataTask for the URL request
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request forHttpRequest:(vx::HttpRequest_SharedPtr*)httpReqPtr {
    // Note: delegate of `session` is `self`
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
        if (dictValue == nil) {
            vxlog_error("[❌][didReceiveResponse] HttpRequest not found in taskMap");
            completionHandler(NSURLSessionResponseCancel);
            return;
        }

        vx::HttpRequest_SharedPtr* httpReqPtr = static_cast<vx::HttpRequest_SharedPtr*>([dictValue pointerValue]);
        if (httpReqPtr == nullptr) {
            vxlog_error("[❌][didReceiveResponse] HttpRequest pointer is NULL. Cancelling the request.");
            completionHandler(NSURLSessionResponseCancel);
            return;
        }

        vx::HttpRequest_SharedPtr httpReq = *httpReqPtr;
        if (httpReq == nullptr) {
            vxlog_error("[❌][didReceiveResponse] HttpRequest shared pointer is NULL. Cancelling the request.");
            completionHandler(NSURLSessionResponseCancel);
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse == nullptr) {
            vxlog_error("[❌][didReceiveResponse] NSHTTPURLResponse is NULL.");
            // TODO: !!! maybe we should change the state of the HttpRequest
            httpReq->getResponse().setSuccess(false);
            httpReq->callCallback();
            return;
        }

        httpReq->getResponse().setSuccess(true);

        // Set response status code
        httpReq->getResponse().setStatusCode(static_cast<uint16_t>(httpResponse.statusCode));

        // Set response headers
        NSDictionary *headers = httpResponse.allHeaderFields;
        std::unordered_map<std::string, std::string> responseHeaders;
        for (NSString *key in headers) {
            NSString *value = headers[key];
            responseHeaders[[key lowercaseString].UTF8String] = value.UTF8String;
        }
        httpReq->getResponse().setHeaders(responseHeaders);

        httpReq->callCallback();
    }
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    @synchronized (_taskMap) {

        NSValue* dictValue = _taskMap[@(dataTask.taskIdentifier)];
        if (dictValue == nil) {
            vxlog_error("[❌][didReceiveData] HttpRequest not found in taskMap");
            return;
        }

        vx::HttpRequest_SharedPtr* httpReqPtr = static_cast<vx::HttpRequest_SharedPtr*>([dictValue pointerValue]);
        if (httpReqPtr == nullptr) {
            vxlog_error("[❌][didReceiveData] HttpRequest pointer is NULL. Cancelling the request.");
            return;
        }

        vx::HttpRequest_SharedPtr httpReq = *httpReqPtr;
        if (httpReq == nullptr) {
            vxlog_error("[❌][didReceiveData] HttpRequest shared pointer is NULL. Cancelling the request.");
            return;
        }

        // Append new data to existing response
        const std::string newBytes(reinterpret_cast<const char*>(data.bytes), data.length);
        httpReq->getResponse().appendBytes(newBytes);

        // Call callback with the updated data
        httpReq->callCallback();
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    @synchronized (_taskMap) {

        NSValue* dictValue = _taskMap[@(task.taskIdentifier)];
        if (dictValue == nil) {
            vxlog_error("[❌][didCompleteWithError] HttpRequest not found in taskMap");
            return;
        }

        vx::HttpRequest_SharedPtr* httpReqPtr = static_cast<vx::HttpRequest_SharedPtr*>([dictValue pointerValue]);
        if (httpReqPtr == nullptr) {
            vxlog_error("[❌][didCompleteWithError] HttpRequest pointer is nullptr");
            return;
        }

        vx::HttpRequest_SharedPtr httpReq = *httpReqPtr;
        if (httpReq == nullptr) {
            vxlog_error("[❌][didCompleteWithError] HttpRequest shared pointer is NULL. Cancelling the request.");
            return;
        }

        if (error) {
            vxlog_error("[❌][didCompleteWithError] ERROR: %s", error.localizedDescription.UTF8String);
            httpReq->setStatus(vx::HttpRequest::Status::FAILED);
            httpReq->getResponse().setSuccess(false);
        } else {
            httpReq->getResponse().setSuccess(true);
            httpReq->getResponse().setDownloadComplete(true);
            httpReq->setStatus(vx::HttpRequest::Status::DONE);
        }

        // Call callback with the updated data
        httpReq->callCallback();

        // Clean up
        // httpReq->_detachPlatformObject(); // done in HttpRequest destructor
        [_taskMap removeObjectForKey:@(task.taskIdentifier)];
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

        NSURLSessionDataTask *task = nil;

        if ((*httpReqPtr)->getOpts().getStreamResponse()) {
            // Create task with the NetworkManager
            task = [[NetworkManager sharedManager] dataTaskWithRequest:request forHttpRequest:httpReqPtr];
        } else { // LEGACY CODE (NO HTTP STREAMING)
            // TODO: !!! send regular HTTP request
            // DO NOT USE DEFAULT COOKIE STORE
            // NSURLSession *session = [NSURLSession sharedSession];
            NSURLSession *session = [NetworkManager sharedManager].session;
            task = [session dataTaskWithRequest:request
                              completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error) {
                    // vxlog_error("HTTP request failed: %s", error.localizedDescription.UTF8String);
                    httpReq->setStatus(HttpRequest::Status::FAILED);
                } else {
                    httpReq->_detachPlatformObject();
                    if (httpReq->getStatus() != HttpRequest::Status::PROCESSING) {
                        vxlog_debug("[🔥] EXIT");
                        return;
                    }
                    NSHTTPURLResponse *httpResponse = static_cast<NSHTTPURLResponse *>(response);

                    // Set response status code
                    const uint16_t statusCode = static_cast<uint16_t>(httpResponse.statusCode);
                    httpReq->getResponse().setStatusCode(statusCode);

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
                    httpReq->getResponse().appendBytes(bodyBytes);

                    httpReq->getResponse().setSuccess(true);
                    httpReq->getResponse().setDownloadComplete(true);
                    httpReq->setStatus(HttpRequest::Status::DONE);
                }

                httpReq->callCallback();
            }];
        }

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
