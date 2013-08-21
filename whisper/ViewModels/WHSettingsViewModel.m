//
//  WHSettingsViewModel.m
//  whisper
//
//  Created by Thomas Goyne on 7/26/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHSettingsViewModel.h"

#import "WHChatClient.h"

static NSSet *validAvaibilityStates() {
    static NSSet *values;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        values = [NSSet setWithObjects:@"", @"away", @"chat", @"dnd", @"xa", nil];
    });
    return values;
}

@interface WHSettingsViewModel ()
@property (nonatomic, strong) WHChatClient *client;
@end

@implementation WHSettingsViewModel
- (instancetype)initWithClient:(WHChatClient *)client {
    self = [super init];
    if (!self) return nil;

    self.client = client;
    self.displayName = client.displayName;
    self.availability = client.availability;
    RAC(self.valid) = [RACSignal
                       combineLatest:@[RACAbleWithStart(self, displayName),
                                       RACAbleWithStart(self, availability)]
                       reduce:^(NSString *displayName, NSString *availability) {
                           return @([displayName length] > 0 &&
                                    [validAvaibilityStates() containsObject:availability]);
                       }];

    return self;
}

- (void)save {
    NSAssert(self.valid, @"Cannot save invalid viewmodel");
    self.client.displayName = self.displayName;
    [self.client setStatus:self.availability];
}
@end
