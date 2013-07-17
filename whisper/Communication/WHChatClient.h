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

/// A class which binds together the CoreData entities and the XMPP stream
@interface WHChatClient : NSObject
+ (WHChatClient *)clientForServer:(NSString *)host port:(uint16_t)port;

- (void)sendMessage:(NSString *)body to:(Contact *)contact;

@property (nonatomic, readonly) NSArray *contacts;
@end
