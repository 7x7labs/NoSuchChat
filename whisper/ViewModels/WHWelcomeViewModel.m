//
//  WHWelcomeViewModel.m
//  whisper
//
//  Created by Thomas Goyne on 9/12/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHWelcomeViewModel.h"

#import "WHChatClient.h"

@interface WHWelcomeViewModel ()
@property (nonatomic) BOOL isFirstRun;
@property (nonatomic) BOOL canSave;
@property (nonatomic, strong) NSString *disabledText;

@property (nonatomic, strong) WHChatClient *client;
@end

@implementation WHWelcomeViewModel
- (instancetype)initWithClient:(WHChatClient *)client {
    if (!(self = [super init])) return self;

    self.client = client;
    self.displayName = client.displayName;

    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"isFirstRun": @YES}];
    self.isFirstRun = [[NSUserDefaults standardUserDefaults] boolForKey:@"isFirstRun"];

    RAC(self.canSave) = [RACSignal
                         combineLatest:@[RACAbleWithStart(self, displayName),
                                         RACAbleWithStart(self.client, connected)]
                         reduce:^(NSString *displayName, NSNumber *connected) {
                             return @([displayName length] > 0
                                   && [displayName rangeOfString:@"\uFFFC"].location == NSNotFound
                                   && [connected boolValue]);
                         }];
    RAC(self, disabledText) = [RACAbleWithStart(self.client, failedToConnect)
                               map:^(NSNumber *value) {
                                   return [value boolValue] ? @"failed to connect to server"
                                                            : @"... connecting ...";
                               }];
    return self;
}

- (void)save {
    NSAssert(self.canSave, @"Cannot save invalid viewmodel");
    self.client.displayName = self.displayName;
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"isFirstRun"];
}
@end
