//
//  WHMultipeerSession.m
//  whisper
//
//  Created by Thomas Goyne on 7/31/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHMultipeerSession.h"

#import <ReactiveCocoa/ReactiveCocoa.h>

@interface WHMultipeerSession () <MCSessionDelegate>
@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, strong) RACSubject *connected;
@property (nonatomic, strong) RACSubject *incomingData;
@end

@implementation WHMultipeerSession
- (instancetype)initWithPeer:(MCPeerID *)peer serviceBrowser:(MCNearbyServiceBrowser *)browser {
    if (!(self = [super init])) return self;
    self.peerID = peer;
    self.session = [[MCSession alloc] initWithPeer:self.peerID];
    self.session.delegate = self;
    [browser invitePeer:self.peerID toSession:self.session withContext:nil timeout:0];
    return self;
}

- (instancetype)initWithPeer:(MCPeerID *)peer invitation:(invitationHandler)invitation {
    if (!(self = [super init])) return self;
    self.peerID = peer;
    self.session = [[MCSession alloc] initWithPeer:self.peerID];
    self.session.delegate = self;
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
            [(RACSubject *)self.connected sendNext:@YES];
            [(RACSubject *)self.connected sendCompleted];
            break;
        case MCSessionStateConnecting:
            break;
        case MCSessionStateNotConnected:
            [(RACSubject *)self.connected sendNext:@NO];
            [(RACSubject *)self.connected sendCompleted];
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
