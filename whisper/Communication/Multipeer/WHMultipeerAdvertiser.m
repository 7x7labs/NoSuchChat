//
//  WHMultipeerAdvertiser.m
//  whisper
//
//  Created by Thomas Goyne on 7/31/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHMultipeerAdvertiser.h"

#import "WHKeyExchangePeer.h"

@interface WHMultipeerAdvertiser () <MCNearbyServiceAdvertiserDelegate>
@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCNearbyServiceAdvertiser *advertiser;
@property (nonatomic, strong) RACSubject *invitations;
@property (nonatomic, strong) NSString *jid;
@end

@implementation WHMultipeerAdvertiser
- (instancetype)initWithJid:(NSString *)jid {
    if (!(self = [super init])) return self;
    self.invitations = [RACSubject subject];
    self.jid = jid;
    return self;
}

- (void)setDisplayName:(NSString *)displayName {
    _displayName = displayName;
    [self setupAdvertiser];
}

- (void)setAdvertising:(BOOL)advertising {
    _advertising = advertising;
    [self setupAdvertiser];
}

- (void)setupAdvertiser {
    [self.advertiser stopAdvertisingPeer];
    self.advertiser = nil;
    if (!self.advertising) return;

    self.peerID = [[MCPeerID alloc] initWithDisplayName:self.displayName];
    self.advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.peerID
                                                        discoveryInfo:@{@"jid": self.jid}
                                                          serviceType:@"7x7-whisper"];
    self.advertiser.delegate = self;
    [self.advertiser startAdvertisingPeer];
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error {
    [(RACSubject *)self.invitations sendError:error];
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser
didReceiveInvitationFromPeer:(MCPeerID *)peerID
       withContext:(NSData *)context
 invitationHandler:(void (^)(BOOL accept, MCSession *session))invitationHandler
{
    NSString *jid = [[NSString alloc] initWithData:context encoding:NSUTF8StringEncoding];
    [(RACSubject *)self.invitations sendNext:[[WHKeyExchangePeer alloc] initWithOwnPeerID:self.peerID
                                                                             remotePeerID:peerID
                                                                                  peerJid:jid
                                                                               invitation:invitationHandler]];
}

@end
