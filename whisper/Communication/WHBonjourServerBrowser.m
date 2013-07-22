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
@property (nonatomic, strong) RACSubject *domains;
@property (nonatomic, strong) NSNetServiceBrowser *serviceBrowser;
@end

@implementation WHBonjourServerBrowser
- (id)init {
    self = [super init];
    if (!self) return self;

    self.domains = [RACSubject subject];

    self.serviceBrowser = [NSNetServiceBrowser new];
    self.serviceBrowser.delegate = self;

    return self;
}

- (void)dealloc {
    [self.serviceBrowser stop];
}

- (RACSignal *)domainNames {
    [self.serviceBrowser searchForServicesOfType:@"_whisper._tcp." inDomain:@"local."];
    return self.domains;
}

#pragma mark -
#pragma mark NSNetServiceBrowserDelegate
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
            didFindDomain:(NSString *)domainName
               moreComing:(BOOL)moreDomainsComing
{
    [self.domains sendNext:domainName];
    if (!moreDomainsComing)
        [self.domains sendCompleted];
}

@end
