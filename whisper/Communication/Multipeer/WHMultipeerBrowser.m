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
@property (nonatomic, strong) NSString *ownJid;
@property (nonatomic, strong) RACSubject *peers;
@property (nonatomic, strong) MCNearbyServiceBrowser *browser;
@end

@implementation WHMultipeerBrowser
- (void)dealloc {
    [self.browser stopBrowsingForPeers];
}

- (instancetype)initWithDisplayName:(NSString *)displayName jid:(NSString *)ownJid {
    if (!(self = [super init])) return self;

    self.ownJid = ownJid;
    self.peers = [RACSubject subject];
    self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:[[MCPeerID alloc] initWithDisplayName:displayName]
                                                    serviceType:@"7x7-whisper"];
    self.browser.delegate = self;

    return self;
}

- (void)startBrowsing {
    [self.browser startBrowsingForPeers];
}

#pragma mark - MCNearbyServiceBrowserDelegate
- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error {
    [(RACSubject *)self.peers sendError:error];
}

- (void)browser:(MCNearbyServiceBrowser *)browser
      foundPeer:(MCPeerID *)peerID
withDiscoveryInfo:(NSDictionary *)info
{
    [(RACSubject *)self.peers sendNext:[[WHMultipeerSession alloc] initWithRemotePeerID:peerID
                                                                                peerJid:info[@"jid"]
                                                                                 ownJid:self.ownJid
                                                                         serviceBrowser:self.browser]];
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID { }
@end
