//
//  WHChatViewModel.h
//  whisper
//
//  Created by Thomas Goyne on 8/28/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class Contact;
@class WHChatClient;

@interface WHChatViewModel : NSObject
@property (nonatomic, readonly) BOOL canSend;
@property (nonatomic, readonly) BOOL online;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSArray *messages;
@property (nonatomic, strong) NSString *message;

- (instancetype)initWithClient:(WHChatClient *)client contact:(Contact *)contact;
- (RACSignal *)send;
@end
