//
//  WHChatViewModel.m
//  whisper
//
//  Created by Thomas Goyne on 8/28/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHChatViewModel.h"

#import "Contact.h"
#import "WHAlert.h"
#import "WHChatClient.h"

@interface WHChatViewModel ()
@property (nonatomic) BOOL valid;
@property (nonatomic, strong) NSArray *messages;

@property (nonatomic, strong) Contact *contact;
@property (nonatomic, strong) WHChatClient *client;
@end

@implementation WHChatViewModel
- (instancetype)initWithClient:(WHChatClient *)client contact:(Contact *)contact {
    if (!(self = [super init])) return self;

    self.client = client;
    self.contact = contact;

    RAC(self, valid) = [RACSignal
                        combineLatest:@[RACAbleWithStart(self, message),
                                        RACAbleWithStart(self, client.connected)]
                        reduce:^(NSString *text, NSNumber *connected) {
                            return @([connected boolValue] && [text length] > 0);
                        }];

    RAC(self, messages) = [RACAbleWithStart(contact, messages)
                          map:^id(id value) {
                            return [value sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc]
                                                                         initWithKey:@"sent" ascending:YES]]];
                          }];

    return self;
}

- (void)send {
    if (!self.valid) return;

    [[self.client sendMessage:self.message to:self.contact]
     subscribeError:^(NSError *error) {
         [WHAlert alertWithMessage:[error description]];
     }];
    self.message = @"";
}

@end
