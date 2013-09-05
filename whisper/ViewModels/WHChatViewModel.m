//
//  WHChatViewModel.m
//  whisper
//
//  Created by Thomas Goyne on 8/28/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHChatViewModel.h"

#import "Contact.h"
#import "Message.h"
#import "WHCoreData.h"
#import "WHChatClient.h"

@interface WHChatViewModel ()
@property (nonatomic) BOOL canSend;
@property (nonatomic) BOOL online;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSArray *messages;

@property (nonatomic, strong) Contact *contact;
@property (nonatomic, strong) WHChatClient *client;
@end

@implementation WHChatViewModel
- (instancetype)initWithClient:(WHChatClient *)client contact:(Contact *)contact {
    if (!(self = [super init])) return self;

    self.client = client;
    self.contact = contact;
    RAC(self, online) = RACAbleWithStart(contact, online);
    RAC(self, title) = RACAbleWithStart(contact, name);

    RAC(self, canSend) = [RACSignal
                          combineLatest:@[RACAbleWithStart(self, message),
                                          RACAbleWithStart(self, client.connected)]
                          reduce:^(NSString *text, NSNumber *connected) {
                              return @([connected boolValue] &&
                                       [text length] > 0 &&
                                       [text rangeOfString:@"\uFFFC"].location == NSNotFound);
                          }];
    NSArray *sortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"sent"
                                                             ascending:YES]];
    NSManagedObjectID *contactID = contact.objectID;
    RAC(self, messages) = [[RACAbleWithStart(contact, messages)
                          map:^id(NSArray *value) {
                            return [value sortedArrayUsingDescriptors:sortDescriptors];
                          }]
                          doNext:^(NSArray *messages) {
                              [WHCoreData modifyObjectWithID:contactID
                                                   withBlock:^(NSManagedObject *obj) {
                                                       [(Contact *)obj setUnreadCount:@0];
                                                   }];
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
