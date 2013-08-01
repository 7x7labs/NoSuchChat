//
//  WHPeerList.m
//  whisper
//
//  Created by Thomas Goyne on 7/22/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHPeerList.h"

#import "WHKeyExchangePeer.h"
#import "WHMultipeerBrowser.h"

#import <EXTScope.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface WHPeerList ()
@property (nonatomic, strong) NSArray *peers;
@property (nonatomic, strong) NSMutableDictionary *peerSet;
@property (nonatomic, strong) WHMultipeerBrowser *browser;
@end

@implementation WHPeerList
- (instancetype)initWithOwnPeerID:(MCPeerID *)ownPeerID {
    if (!(self = [super init])) return self;

    self.peers = @[];
    self.peerSet = [NSMutableDictionary new];
    self.browser = [[WHMultipeerBrowser alloc] initWithPeer:ownPeerID];

    @weakify(self)
    [self.browser.peers subscribeNext:^(MCPeerID *peer) {
        if ([peer isEqual:ownPeerID]) return;
        @strongify(self)
        self.peerSet[peer] = [[WHKeyExchangePeer alloc] initWithPeerID:peer browser:self.browser];
        self.peers = [self.peerSet allValues];
    }];
    [self.browser.removedPeers subscribeNext:^(MCPeerID *peer) {
        @strongify(self)
        [self.peerSet removeObjectForKey:peer];
        self.peers = [self.peerSet allValues];
    }];

    [self.browser startBrowsing];

    return self;
}
@end
