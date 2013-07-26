//
//  WHKeyExchangePeer.h
//  whisper
//
//  Created by Thomas Goyne on 7/23/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class RACSignal;
@class WHKeyExchangeClient;

@interface WHKeyExchangePeer : NSObject
@property (nonatomic, readonly) NSString *name;
// Maybe a picture too or something?

@property (nonatomic, readonly) BOOL wantsToConnect;
@property (nonatomic, readonly) RACSignal *connected;

- (void)connect;

- (instancetype)initWithName:(NSString *)name
                         jid:(NSString *)jid
                      client:(WHKeyExchangeClient *)client;
@end
