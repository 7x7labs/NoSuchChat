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
@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic) uint16_t port;
@property (nonatomic, strong) RACSubject *clients;
@property (nonatomic, strong) NSData *introData;
@end

@implementation WHKeyExchangeServer
- (instancetype)initWithIntroData:(NSData *)introData {
    self = [super init];
    if (!self) return self;

    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:nil];
    RACBind(self.port) = RACBind(self.socket.localPort);
    self.clients = [RACReplaySubject subject];
    self.introData = introData;

    NSError *error;
    if (![self.socket acceptOnPort:0 error:&error]) {
        NSLog(@"Error listening on socket: %@", error);
        return nil;
    }

    return self;
}

# pragma mark - GCDAsyncSocket delegate
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    [self.clients sendNext:[[WHKeyExchangeClient alloc] initWithSocket:newSocket
                                                             introData:self.introData]];
}
@end
