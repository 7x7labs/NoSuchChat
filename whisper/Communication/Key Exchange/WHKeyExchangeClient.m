//
//  WHKeyExchangeClient.m
//  whisper
//
//  Created by Thomas Goyne on 7/23/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHKeyExchangeClient.h"

#import "WHKeyExchangePeer.h"

#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface WHKeyExchangeClient ()
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, strong) NSData *introData;
@property (nonatomic, strong) RACReplaySubject *peer;
@property (nonatomic, strong) RACReplaySubject *publicKey;
@end

@implementation WHKeyExchangeClient
- (instancetype)init {
    self = [super init];
    if (self) {
        self.peer = [RACReplaySubject subject];
        self.publicKey = [RACReplaySubject subject];
    }
    return self;
}

- (instancetype)initWithSocket:(GCDAsyncSocket *)socket introData:(NSData *)introData {
    self = [self init];
    if (self) {
        self.introData = introData;
        self.socket = socket;
        self.socket.delegate = self;
        [self writeData:introData];
        [self read];
    }
    return self;
}

- (instancetype)initWithDomain:(NSString *)domain
                          port:(uint16_t)port
                     introData:(NSData *)introData
{
    self = [self init];
    if (!self) return self;

    self.introData = introData;
    self.queue = dispatch_queue_create("com.7x7labs.whisper.keyex.client", NULL);
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.queue];

    NSError *error;
    if (![self.socket connectToHost:domain onPort:port error:&error])
        [self.peer sendError:error];

    [self writeData:introData];
    [self read];

    return self;
}

- (void)read {
    [self.socket readDataToData:[GCDAsyncSocket ZeroData]
                    withTimeout:-1
                            tag:0];
}

- (void)writeData:(NSData *)data {
    [self.socket writeData:data withTimeout:-1 tag:0];
    [self.socket writeData:[GCDAsyncSocket ZeroData] withTimeout:-1 tag:0];
}

- (void)sendKey:(NSData *)key {
    [self writeData:[NSJSONSerialization dataWithJSONObject:@{@"key": key}
                                                    options:0 error:nil]];
}

# pragma mark - GCDAsyncSocket delegate
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if (![data length]) return;

    // Remove NUL terminator if present
    if (!*((uint8_t *)[data bytes] + [data length] - 1))
        data = [data subdataWithRange:NSMakeRange(0, [data length] - 1)];

    NSError *error;
    NSDictionary *message = [NSJSONSerialization JSONObjectWithData:data
                                                            options:0
                                                              error:&error];
    if (error) {
        [self.peer sendError:error];
        return;
    }
    if (![message isKindOfClass:[NSDictionary class]]) {
        [self.peer sendError:error]; // ...
        return;
    }

    NSDictionary *info;
    if ((info = message[@"info"]))
        [self.peer sendNext:[[WHKeyExchangePeer alloc] initWithName:info[@"name"]
                                                                jid:info[@"jid"]
                                                             client:self]];
    else if ((info = message[@"key"]))
        [self.publicKey sendNext:info];
}

@end
