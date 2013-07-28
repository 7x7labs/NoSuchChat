//
//  WHXMPPRoster.h
//  whisper
//
//  Created by Thomas Goyne on 7/26/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class Contact;
@class RACSignal;
@class XMPPStream;

@interface WHXMPPRoster : NSObject
@property (nonatomic, strong) NSMutableSet *contactJids;

- (instancetype)initWithXmppStream:(XMPPStream *)stream;

- (void)addContact:(Contact *)contact;
- (void)removeContact:(Contact *)contact;
@end
