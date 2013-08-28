//
//  WHChatClient.h
//  whisper
//
//  Created by Thomas Goyne on 7/17/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class Contact;
@class WHXMPPWrapper;

/// A class which binds together the CoreData entities and the XMPP stream
@interface WHChatClient : NSObject
+ (WHChatClient *)clientForServer:(NSString *)host port:(uint16_t)port;
+ (WHChatClient *)clientForServer:(NSString *)host port:(uint16_t)port stream:(WHXMPPWrapper *)xmpp;

- (RACSignal *)sendMessage:(NSString *)body to:(Contact *)contact;
- (void)setStatus:(NSString *)status;

@property (nonatomic, readonly) NSArray *contacts;
@property (nonatomic, readonly) NSString *jid;
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, readonly) NSString *availability;
@property (nonatomic, readonly) BOOL connected;

@property (nonatomic, readonly) MCPeerID *peerID;
@property (nonatomic, readonly) RACSignal *incomingMessages;
@end
