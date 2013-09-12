//
//  WHSettingsViewModel.m
//  whisper
//
//  Created by Thomas Goyne on 7/26/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHSettingsViewModel.h"

#import "Contact.h"
#import "wHAccount.h"
#import "WHChatClient.h"
#import "WHKeyPair.h"

@interface WHSettingsViewModel ()
@property (nonatomic, strong) WHChatClient *client;
@end

@implementation WHSettingsViewModel
- (instancetype)initWithClient:(WHChatClient *)client {
    self = [super init];
    if (!self) return nil;

    self.client = client;
    self.displayName = client.displayName;
    
    RAC(self.valid) = [RACAbleWithStart(self, displayName)
                       map:^(NSString *displayName) {
                           return @([displayName length] > 0 &&
                           [displayName rangeOfString:@"\uFFFC"].location == NSNotFound);
                       }];

    return self;
}

- (void)save {
    NSAssert(self.valid, @"Cannot save invalid viewmodel");
    self.client.displayName = self.displayName;
}

- (void)deleteAll {
    self.deleting = YES;

    for (Contact *contact in [Contact all])
        [contact delete];

    [self.client disconnect];
    [WHKeyPair deleteAll];
    [WHAccount delete];

    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"isFirstRun"];
    [[NSUserDefaults standardUserDefaults] setObject:@"Nickname" forKey:@"displayName"];

    self.deleting = NO;
}
@end
