//
//  WHChatClient.h
//  whisper
//
//  Created by Thomas Goyne on 7/17/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Contact;
@class RACSignal;
@protocol WHXMPPStream;

/// A class which binds together the CoreData entities and the XMPP stream
@interface WHChatClient : NSObject
+ (WHChatClient *)clientForServer:(NSString *)host port:(uint16_t)port;
+ (WHChatClient *)clientForServer:(NSString *)host port:(uint16_t)port stream:(id<WHXMPPStream>)xmpp;

- (RACSignal *)sendMessage:(NSString *)body to:(Contact *)contact;

@property (nonatomic, readonly) NSArray *contacts;
@property (nonatomic, readonly) NSString *jid;
@property (nonatomic, strong) NSString *displayName;

@property (nonatomic, readonly) RACSignal *incomingMessages;
@end
