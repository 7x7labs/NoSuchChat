//
//  WHMultipeerAdvertiser.m
//  whisper
//
//  Created by Thomas Goyne on 7/31/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHMultipeerAdvertiser.h"

#import "WHMultipeerSession.h"

@interface WHMultipeerAdvertiser () <MCNearbyServiceAdvertiserDelegate>
@property (nonatomic, strong) NSString *jid;
@property (nonatomic, strong) NSString *displayName;

@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCNearbyServiceAdvertiser *advertiser;
@property (nonatomic, strong) RACSubject *incoming;
@end

@implementation WHMultipeerAdvertiser
- (instancetype)initWithJid:(NSString *)jid displayName:(NSString *)displayName {
    if (!(self = [super init])) return self;
    self.incoming = [RACSubject subject];
    self.jid = jid;
    self.displayName = displayName;
    self.peerID = [[MCPeerID alloc] initWithDisplayName:displayName];
    return self;
}

- (void)setAdvertising:(BOOL)advertising {
    _advertising = advertising;
    [self.advertiser stopAdvertisingPeer];
    self.advertiser = nil;
    if (!self.advertising) return;

    self.advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.peerID
                                                        discoveryInfo:@{@"jid": self.jid}
                                                          serviceType:@"7x7-whisper"];
    self.advertiser.delegate = self;
    [self.advertiser startAdvertisingPeer];
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error {
    [(RACSubject *)self.incoming sendError:error];
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser
didReceiveInvitationFromPeer:(MCPeerID *)peerID
       withContext:(NSData *)context
 invitationHandler:(void (^)(BOOL accept, MCSession *session))invitationHandler
{
    NSString *jid = [[NSString alloc] initWithData:context encoding:NSUTF8StringEncoding];
    if ([self.jid isEqualToString:jid]) return;
    [(RACSubject *)self.incoming sendNext:[[WHMultipeerSession alloc] initWithSelf:self.peerID
                                                                            remote:peerID
                                                                           peerJid:jid
                                                                        invitation:invitationHandler
                                                                        advertiser:self]];
}

@end
