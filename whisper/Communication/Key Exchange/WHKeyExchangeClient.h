//
//  WHKeyExchangeClient.h
//  whisper
//
//  Created by Thomas Goyne on 7/23/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class GCDAsyncSocket;
@class RACSubject;

@interface WHKeyExchangeClient : NSObject
- (instancetype)initWithDomain:(NSString *)domain port:(uint16_t)port;
- (instancetype)initWithSocket:(GCDAsyncSocket *)socket;

- (void)sendKey:(NSData *)key;

@property (nonatomic, readonly) RACSubject *peer;
@property (nonatomic, readonly) RACSubject *publicKey;
@end
