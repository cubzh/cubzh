//
//  WSConnection.mm
//  xptools
//
//  Created by Adrien Duermael on 10/21/2024.
//  Copyright © 2024 voxowl. All rights reserved.
//

#include "WSConnection.hpp"

// Obj-C
#import <Foundation/Foundation.h>

// xptools
#include "vxlog.h"

@interface WebSocketConnection : NSObject <NSURLSessionWebSocketDelegate>
@property (nonatomic, strong, readwrite) NSURLSession *session;
@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, strong, readwrite) NSURLSessionWebSocketTask *task;
@property vx::WSConnection *conn;
@end

@implementation WebSocketConnection
@synthesize session = _session;
@synthesize url = _url;
@synthesize task = _task;
@synthesize conn = _conn;

- (instancetype)init {
    return [self initWithWSConnection:nil];
}

- (void)dealloc {
    [self.task cancel];
    [self.session invalidateAndCancel];
}

- (instancetype)initWithWSConnection:(vx::WSConnection*)conn {
    self = [super init];
    if (self) {
        // NSLog(@"WebSocket connection INIT");
        _conn = conn;
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        NSString *str = [NSString stringWithUTF8String:conn->getURL().c_str()];
        _url = [NSURL URLWithString:str];
        // NSLog(@"WebSocket connection URL: %@", _url);
    }
    return self;
}

-(void)close {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.task) {
            // [self.task cancel];
            [self.task cancelWithCloseCode:NSURLSessionWebSocketCloseCodeNormalClosure reason:nil];
        }
        if (self.session) {
            [self.session invalidateAndCancel];
        }
        self.task = nil;
        self.session = nil;
    });
}

-(void)connect {
    [self close];
    dispatch_async(dispatch_get_main_queue(), ^{
        // NSLog(@"WebSocket connection CONNECT");
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
        self.task = [self.session webSocketTaskWithURL:self.url];
        [[self task] resume];
    });
}

- (void)URLSession:(NSURLSession *)session webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask didOpenWithProtocol:(NSString *)protocol {
    NSLog(@"WebSocket connection ESTABLISHED");

    [self conn]->established();

    std::shared_ptr<vx::ConnectionDelegate> delegate = [self conn]->getDelegate().lock();
    if (delegate != nullptr) {
        delegate->connectionDidEstablish(*[self conn]);
    }

    [self readNextMessage];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        // NSLog(@"WebSocket connection task failed");
        NSLog(@"WebSocket connection task failed with error: %@", error);
        [self conn]->closeOnError();
    }
}

- (void)URLSession:(NSURLSession *)session webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask didCloseWithCode:(NSURLSessionWebSocketCloseCode)closeCode reason:(NSData *)reason {
    NSLog(@"WebSocket connection CLOSED with code: %ld", static_cast<long>(closeCode));
}

-(void)send:(NSURLSessionWebSocketMessage *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.task sendMessage:msg completionHandler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"WebSocket connection ERROR sending message: %@", error);
            }
        }];
    });
}

- (void)readNextMessage {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage * _Nullable message, NSError * _Nullable error) {
            if (error) {
                // NSLog(@"WebSocket connection ERROR receiving message: %@", error);
                // connection already closed within `didCompleteWithError`
                // self.conn->closeOnError();
                return;
            }

            if (message) {
                std::shared_ptr<vx::ConnectionDelegate> delegate = self.conn->getDelegate().lock();
                if (delegate != nullptr) {
                    if (message.type == NSURLSessionWebSocketMessageTypeData) {
                        // NSLog(@"WebSocket connection received message (DATA)");
                        NSData *data = message.data;
                        const char *bytes = reinterpret_cast<const char *>([data bytes]);
                        NSUInteger length = [data length];

                        if (bytes != nullptr && length > 0) {
                            char *buffer = static_cast<char *>(malloc(length));
                            memcpy(buffer, bytes, length);

                            vx::WSConnection::Payload_SharedPtr pld = vx::WSConnection::Payload::decode(buffer, length);
                            pld->step("WSConnection::receivedBytes");
                            delegate->connectionDidReceive(*self.conn, pld);
                        } else {
                            vxlog_error("[WSConnection::receivedBytes] dropped bytes");
                        }

                    } else if (message.type == NSURLSessionWebSocketMessageTypeString) {
                        // NSLog(@"WebSocket connection received message (STRING): %@", message.string);
                        NSString *text = message.string;
                        const char *utf8String = [text UTF8String];

                        if (utf8String != nullptr) {
                            size_t length = strlen(utf8String);
                            char *buffer = static_cast<char *>(malloc(length));
                            memcpy(buffer, utf8String, length);

                            vx::WSConnection::Payload_SharedPtr pld = vx::WSConnection::Payload::decode(buffer, length);
                            pld->step("WSConnection::receivedBytes");
                            delegate->connectionDidReceive(*self.conn, pld);
                        } else {
                            vxlog_error("[WSConnection::receivedBytes] dropped bytes");
                        }
                    }
                }
            }

            [self readNextMessage];
        }];
    });
}
@end

namespace vx {

void WSConnection::_init() {}

void WSConnection::_connect() {

    if (_platformObject == nullptr) {
        WebSocketConnection *c = [[WebSocketConnection alloc] initWithWSConnection:this];
        _attachPlatformObject((__bridge_retained void*)c);
    }

    [(__bridge WebSocketConnection*)_platformObject connect];
}

void WSConnection::_writePayload(const Payload_SharedPtr& p) {
    if (_platformObject == nullptr) {
        return;
    }

    p->createMetadataIfNull();
    char *metadata = p->getMetadata();
    size_t metaDataSize = p->metadataSize();
    NSMutableData *data = [NSMutableData dataWithBytes:metadata length:metaDataSize];
    [data appendBytes:p->getContent() length:p->contentSize()];

    NSURLSessionWebSocketMessage *webSocketMessage = [[NSURLSessionWebSocketMessage alloc] initWithData:data];
    [(__bridge WebSocketConnection*)_platformObject send:webSocketMessage];
}

void WSConnection::_close() {
    if (_platformObject == nullptr) {
        return;
    }
    [(__bridge WebSocketConnection*)_platformObject close];
    _detachPlatformObject();
}

void WSConnection::_destroy() {
    if (_platformObject == nullptr) {
        return;
    }
    [(__bridge WebSocketConnection*)_platformObject close];
    _detachPlatformObject();
}

void WSConnection::_attachPlatformObject(void *o) {
    if (_platformObject != nullptr) {
        _detachPlatformObject();
    }
    _platformObject = o;
}

void WSConnection::_detachPlatformObject() {
    if (_platformObject == nullptr) {
        return;
    }
    CFRelease(_platformObject);
    _platformObject = nullptr;
}

}
