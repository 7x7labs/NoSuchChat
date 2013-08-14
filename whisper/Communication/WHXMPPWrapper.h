//
//  WHXMPPWrapper.h
//  whisper
//
//  Created by Thomas Goyne on 7/16/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class WHXMPPRoster;

@interface WHChatMessage : NSObject
@property (nonatomic, strong) NSString *senderJid;
@property (nonatomic, strong) NSString *body;
@property (nonatomic, strong) NSDate *sent;

- (WHChatMessage *)initWithSenderJid:(NSString *)senderJid body:(NSString *)body sent:(NSDate *)sent;
@end

@interface WHXMPPWrapper : NSObject
- (RACSignal *)connectToServer:(NSString *)server
                          port:(uint16_t)port
                      username:(NSString *)username
                      password:(NSString *)password;

/// Send a message to the given Jabber ID
- (RACSignal *)sendMessage:(NSString *)body to:(NSString *)recipient;

/// A push sequence of WHChatMessages
@property (nonatomic, readonly) RACSignal *messages;
@property (nonatomic, readonly) WHXMPPRoster *roster;
@property (nonatomic, strong) NSString *displayName;
@end
