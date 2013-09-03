//
//  WHSettingsViewModel.m
//  whisper
//
//  Created by Thomas Goyne on 7/26/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHSettingsViewModel.h"

#import "WHChatClient.h"

@interface WHSettingsViewModel ()
@property (nonatomic, strong) WHChatClient *client;
@end

@implementation WHSettingsViewModel
- (instancetype)initWithClient:(WHChatClient *)client {
    self = [super init];
    if (!self) return nil;

    self.client = client;
    self.displayName = client.displayName;
    
    RAC(self.valid) = [RACSignal
                       combineLatest:@[RACAbleWithStart(self, displayName)]
                       reduce:^(NSString *displayName) {
                           return @([displayName length] > 0 &&
                                    [displayName rangeOfString:@"\uFFFC"].location == NSNotFound);
                       }];

    return self;
}

- (void)save {
    NSAssert(self.valid, @"Cannot save invalid viewmodel");
    self.client.displayName = self.displayName;
}
@end
