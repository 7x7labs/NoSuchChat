//
//  WHContactListViewModel.m
//  whisper
//
//  Created by Thomas Goyne on 8/29/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHContactListViewModel.h"

#import "Contact.h"
#import "WHAvatar.h"
#import "WHChatClient.h"

@interface WHContactRowViewModel ()
@property (nonatomic, strong) UIImage *avatar;
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, strong) NSNumber *status;
@property (nonatomic, strong) NSString *unreadCount;
@end

@implementation WHContactRowViewModel
- (instancetype)initWithContact:(Contact *)contact {
    if (!(self = [super init])) return self;

    // Note: one-way bindings since that's all that makes sense at the moment
    RAC(self, avatar) = [RACAbleWithStart(contact, jid) map:^id(NSString *jid) {
        return jid ? [WHAvatar avatarForEmail:jid] : nil;
    }];
    RAC(self, unreadCount) = [RACAbleWithStart(contact, unreadCount) map:^id(NSNumber *value) {
        return [value intValue] > 0 ? [value stringValue] : @"";
    }];
    
    RAC(self, displayName) = RACAbleWithStart(contact, name);
    RAC(self, status) = [RACAbleWithStart(contact, online) map:^id(id value) { return value ?: @NO; }];

    return self;
}

@end

@interface WHContactListViewModel ()
@property (nonatomic, strong) NSArray *contacts;
@property (nonatomic) NSInteger count;
@end

@implementation WHContactListViewModel
- (instancetype)initWithClient:(WHChatClient *)client {
    if (!(self = [super init])) return self;

    RAC(self, contacts) = RACAbleWithStart(client, contacts);
    RAC(self, count) = [RACAbleWithStart(self, contacts) map:^(NSArray *contacts) {
        return @([contacts count]);
    }];

    return self;
}

- (WHContactRowViewModel *)objectAtIndexedSubscript:(NSUInteger)index {
    return [[WHContactRowViewModel alloc] initWithContact:self.contacts[index]];
}

- (Contact *)rawContactAtIndex:(NSUInteger)index {
    return self.contacts[index];
}

- (void)deleteContactAtIndex:(NSUInteger)index {
    [self.contacts[index] delete];
}

@end
