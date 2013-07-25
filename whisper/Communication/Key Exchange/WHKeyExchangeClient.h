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
- (instancetype)initWithDomain:(NSString *)domain
                          port:(uint16_t)port
                     introData:(NSData *)introData;
- (instancetype)initWithSocket:(GCDAsyncSocket *)socket introData:(NSData *)introData;

- (void)sendKey:(NSData *)key;

@property (nonatomic, readonly) RACSubject *peer;
@property (nonatomic, readonly) RACSubject *publicKey;
@property (nonatomic, readonly) NSData *introData;
@end
