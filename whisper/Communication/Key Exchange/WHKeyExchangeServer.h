//
//  WHKeyExchangeServer.h
//  whisper
//
//  Created by Thomas Goyne on 7/23/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class RACSubject;

@interface WHKeyExchangeServer : NSObject
@property (nonatomic, readonly) uint16_t port;
@property (nonatomic, readonly) RACSubject *clients;
@end
