//
//  WHChatViewModel.m
//  whisper
//
//  Created by Thomas Goyne on 8/28/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHChatViewModel.h"

#import "Contact.h"
#import "WHChatClient.h"

@interface WHChatViewModel ()
@property (nonatomic) BOOL canSend;
@property (nonatomic, strong) NSArray *messages;

@property (nonatomic, strong) Contact *contact;
@property (nonatomic, strong) WHChatClient *client;
@end

@implementation WHChatViewModel
- (instancetype)initWithClient:(WHChatClient *)client contact:(Contact *)contact {
    if (!(self = [super init])) return self;

    self.client = client;
    self.contact = contact;

    RAC(self, canSend) = [RACSignal
                          combineLatest:@[RACAbleWithStart(self, message),
                                          RACAbleWithStart(self, client.connected)]
                          reduce:^(NSString *text, NSNumber *connected) {
                              return @([connected boolValue] &&
                                       [text length] > 0 &&
                                       [text rangeOfString:@"\uFFFC"].location == NSNotFound);
                          }];

    RAC(self, messages) = [RACAbleWithStart(contact, messages)
                          map:^id(id value) {
                            return [value sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc]
                                                                         initWithKey:@"sent" ascending:YES]]];
                          }];

    return self;
}

- (RACSignal *)send {
    if (!self.canSend) return [RACSignal empty];

    RACSignal *result = [self.client sendMessage:self.message to:self.contact];
    self.message = @"";
    return result;
}

@end
