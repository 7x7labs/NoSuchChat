//
//  WHBonjourServerBrowser.m
//  whisper
//
//  Created by Thomas Goyne on 7/22/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHBonjourServerBrowser.h"

#import <ReactiveCocoa/ReactiveCocoa.h>

@interface WHBonjourServerBrowser () <NSNetServiceBrowserDelegate, NSNetServiceDelegate>
@property (nonatomic, strong) RACSubject *services;
@property (nonatomic, strong) NSNetServiceBrowser *serviceBrowser;
@property (nonatomic, strong) NSMutableSet *resolving;
@end

@implementation WHBonjourServerBrowser
- (id)init {
    self = [super init];
    if (!self) return self;

    self.services = [RACSubject subject];
    self.resolving = [NSMutableSet set];

    self.serviceBrowser = [NSNetServiceBrowser new];
    self.serviceBrowser.delegate = self;
    [self.serviceBrowser scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

    return self;
}

- (void)dealloc {
    [self.serviceBrowser stop];
    [self.services sendCompleted];
}

- (RACSignal *)netServices {
    [self.serviceBrowser searchForServicesOfType:@"_whisper._tcp" inDomain:@"local."];
    return self.services;
}

#pragma mark - NSNetServiceBrowserDelegate
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
           didFindService:(NSNetService *)netService
               moreComing:(BOOL)moreServicesComing
{
    NSLog(@"Resolving service \"%@\"", netService.name);
    [self.resolving addObject:netService];

    netService.delegate = self;
    [netService resolveWithTimeout:5.0];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
             didNotSearch:(NSDictionary *)errorInfo
{
    NSLog(@"did not search: %@", errorInfo);
}

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)netServiceBrowser {
    NSLog(@"will search");
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)netServiceBrowser {
    NSLog(@"stopped search");
}

#pragma mark - NSNetServiceDelegate
- (void)netServiceDidResolveAddress:(NSNetService *)netService {
    NSLog(@"Resolved %@", netService.name);
    [self.services sendNext:netService];
    [self.resolving removeObject:netService];
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    NSLog(@"Error resolving bonjour net service: %@", errorDict);
    [self.resolving removeObject:sender];
}

@end
