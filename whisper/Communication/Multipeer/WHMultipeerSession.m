//
//  WHMultipeerSession.m
//  whisper
//
//  Created by Thomas Goyne on 7/31/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHMultipeerSession.h"

#import "WHMultipeerAdvertiser.h"
#import "WHMultipeerPacket.h"

@interface WHMultipeerSession () <MCSessionDelegate>
@property (nonatomic, strong) NSString *peerJid;
@property (nonatomic) BOOL connected;
@property (nonatomic, strong) RACReplaySubject *incomingData;
@property (nonatomic, weak) WHMultipeerAdvertiser *advertiser;

@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;
@end

@implementation WHMultipeerSession
- (void)dealloc {
    [self.session disconnect];
}

- (instancetype)initWithSelf:(MCPeerID *)ownPeer remote:(MCPeerID *)remotePeer jid:(NSString *)jid {
    if (!(self = [super init])) return self;
    self.peerJid = jid;
    self.peerID = remotePeer;
    self.session = [[MCSession alloc] initWithPeer:ownPeer
                                  securityIdentity:nil
                              encryptionPreference:MCEncryptionNone];
    self.session.delegate = self;
    self.incomingData = [RACReplaySubject replaySubjectWithCapacity:1];
    return self;
}

- (instancetype)initWithRemotePeerID:(MCPeerID *)remotePeer
                             peerJid:(NSString *)peerJid
                              ownJid:(NSString *)ownJid
                      serviceBrowser:(MCNearbyServiceBrowser *)browser
{
    if (!(self = [self initWithSelf:browser.myPeerID remote:remotePeer jid:peerJid])) return self;
    [browser invitePeer:self.peerID
              toSession:self.session
            withContext:[ownJid dataUsingEncoding:NSUTF8StringEncoding]
                timeout:0];
    return self;
}

- (instancetype)initWithSelf:(MCPeerID *)ownPeer
                      remote:(MCPeerID *)remotePeer
                     peerJid:(NSString *)peerJid
                  invitation:(invitationHandler)invitation
                  advertiser:(WHMultipeerAdvertiser *)advertiser
{
    if (!(self = [self initWithSelf:ownPeer remote:remotePeer jid:peerJid])) return self;
    self.advertiser = advertiser;
    invitation(YES, self.session);
    return self;
}

- (NSError *)sendData:(NSData *)data {
    NSError *error = nil;
    [self.session sendData:data
                   toPeers:@[self.peerID]
                  withMode:MCSessionSendDataReliable
                     error:&error];
    return error;
}

#pragma mark - MCSessionDelegate
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    switch (state) {
        case MCSessionStateConnected:
            self.connected = YES;
            break;
        case MCSessionStateConnecting:
            break;
        case MCSessionStateNotConnected:
            if (self.connected)
                self.advertiser.advertising = self.advertiser.advertising;
            self.connected = NO;
            break;
    }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    [(RACSubject *)self.incomingData sendNext:data];
}

// Required methods we don't use
- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error { }
- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID { }
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress { }

@end
