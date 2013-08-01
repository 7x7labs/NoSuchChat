//
//  WHKeyExchangePeer.m
//  whisper
//
//  Created by Thomas Goyne on 7/23/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHKeyExchangePeer.h"

#import "Contact.h"
#import "WHKeyPair.h"
#import "WHMultipeerBrowser.h"
#import "WHMultipeerSession.h"

#import <ReactiveCocoa/ReactiveCocoa.h>

@interface WHKeyExchangePeer ()
@property (nonatomic, strong) NSString *name;

@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) WHMultipeerBrowser *browser;
@property (nonatomic, strong) invitationHandler invitation;
@end

@implementation WHKeyExchangePeer
- (instancetype)initWithPeerID:(MCPeerID *)peerID {
    if (!(self = [super init])) return self;

    self.name = peerID.displayName;
    self.peerID = peerID;

    return self;
}

- (instancetype)initWithPeerID:(MCPeerID *)peerID
                       browser:(WHMultipeerBrowser *)browser
{
    if (!(self = [self initWithPeerID:peerID])) return self;
    self.browser = browser;
    return self;
}

- (instancetype)initWithPeerID:(MCPeerID *)peerID
                    invitation:(invitationHandler)invitation
{
    if (!(self = [self initWithPeerID:peerID])) return self;
    self.invitation = invitation;
    return self;
}

- (RACSignal *)connectWithJid:(NSString *)jid {
    NSAssert(!!self.browser != !!self.invitation,
             @"WHKeyExchangePeer needs a service browser or invitation handler to connect");

    WHMultipeerSession *session;
    if (self.browser)
        session = [self.browser connectToPeer:self.peerID];
    else
        session = [[WHMultipeerSession alloc] initWithPeer:self.peerID invitation:self.invitation];

    __block NSString *contactJid = nil;
    return [[[session.connected
              flattenMap:^RACStream *(NSNumber *didConnect) {
                  NSError *error = [session sendData:[jid dataUsingEncoding:NSUTF8StringEncoding]];
                  return error ? [RACSignal error:error] : [session.incomingData take:1];
              }]
              flattenMap:^RACStream *(NSData *jidData) {
                  contactJid = [[NSString alloc] initWithData:jidData encoding:NSUTF8StringEncoding];
                  NSError *error = [session sendData:[WHKeyPair createKeyPairForJid:contactJid].publicKeyBits];
                  return error ? [RACSignal error:error] : [session.incomingData take:1];
              }]
              map:^(NSData *publicKey) {
                  [WHKeyPair addKey:publicKey fromJid:contactJid];
                  return [Contact createWithName:self.name jid:contactJid];
              }];
}

- (void)reject {
    NSAssert(self.invitation, @"Can only reject incoming connections");
    self.invitation(NO, nil);
    self.invitation = nil;
}
@end
