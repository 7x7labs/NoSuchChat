//
//  WHMultipeerBrowser.m
//  whisper
//
//  Created by Thomas Goyne on 7/31/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHMultipeerBrowser.h"

#import "WHMultipeerSession.h"

@interface WHMultipeerBrowser () <MCNearbyServiceBrowserDelegate>
@property (nonatomic, strong) RACSubject *peers;
@property (nonatomic, strong) RACSubject *removedPeers;
@property (nonatomic, strong) MCNearbyServiceBrowser *browser;
@end

@implementation WHMultipeerBrowser
- (void)dealloc {
    [self.browser stopBrowsingForPeers];
}

- (instancetype)initWithPeer:(MCPeerID *)peerID {
    if (!(self = [super init])) return self;

    self.peers = [RACSubject subject];
    self.removedPeers = [RACSubject subject];
    self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:peerID
                                                    serviceType:@"7x7-whisper"];
    self.browser.delegate = self;

    return self;
}

- (void)startBrowsing {
    [self.browser startBrowsingForPeers];
}

- (WHMultipeerSession *)connectToPeer:(MCPeerID *)peerID ownJid:(NSString *)jid {
    return [[WHMultipeerSession alloc] initWithRemotePeerID:peerID
                                                     ownJid:jid
                                             serviceBrowser:self.browser];
}

#pragma mark - MCNearbyServiceBrowserDelegate
- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error {
    [(RACSubject *)self.peers sendError:error];
}

- (void)browser:(MCNearbyServiceBrowser *)browser
      foundPeer:(MCPeerID *)peerID
withDiscoveryInfo:(NSDictionary *)info
{
    [(RACSubject *)self.peers sendNext:RACTuplePack(peerID, info[@"jid"])];
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID {
    [(RACSubject *)self.removedPeers sendNext:peerID];
}
@end
