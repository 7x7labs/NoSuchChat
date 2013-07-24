//
//  WHBonjourServerBrowser.m
//  whisper
//
//  Created by Thomas Goyne on 7/22/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHBonjourServerBrowser.h"

#import <ReactiveCocoa/ReactiveCocoa.h>

@interface WHBonjourServerBrowser () <NSNetServiceBrowserDelegate>
@property (nonatomic, strong) RACSubject *services;
@property (nonatomic, strong) NSNetServiceBrowser *serviceBrowser;
@end

@implementation WHBonjourServerBrowser
- (id)init {
    self = [super init];
    if (!self) return self;

    self.services = [RACSubject subject];

    self.serviceBrowser = [NSNetServiceBrowser new];
    self.serviceBrowser.delegate = self;

    return self;
}

- (void)dealloc {
    [self.serviceBrowser stop];
}

- (RACSignal *)netServices {
    [self.serviceBrowser searchForServicesOfType:@"_whisper._tcp." inDomain:@"local."];
    return self.services;
}

#pragma mark -
#pragma mark NSNetServiceBrowserDelegate
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
           didFindService:(NSNetService *)netService
               moreComing:(BOOL)moreServicesComing
{
    [self.services sendNext:netService];
    if (!moreServicesComing)
        [self.services sendCompleted];
}

@end
