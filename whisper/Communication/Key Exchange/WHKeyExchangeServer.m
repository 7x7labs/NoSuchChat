//
//  WHKeyExchangeServer.m
//  whisper
//
//  Created by Thomas Goyne on 7/23/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHKeyExchangeServer.h"

#import "WHKeyExchangeClient.h"

#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface WHKeyExchangeServer ()
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic) uint16_t port;
@property (nonatomic, strong) RACSubject *clients;
@end

@implementation WHKeyExchangeServer
- (instancetype)init {
    self = [super init];
    if (!self) return self;

    self.queue = dispatch_queue_create("com.7x7labs.whisper.keyex.server", NULL);
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.queue];
    RACBind(self.port) = RACBind(self.socket.localPort);
    self.clients = [RACReplaySubject subject];

    NSError *error;
    if (![self.socket acceptOnPort:0 error:&error]) {
        NSLog(@"Error listening on socket: %@", error);
        return nil;
    }

    return self;
}

# pragma mark - GCDAsyncSocket delegate
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    [self.clients sendNext:[[WHKeyExchangeClient alloc] initWithSocket:newSocket]];
}
@end
