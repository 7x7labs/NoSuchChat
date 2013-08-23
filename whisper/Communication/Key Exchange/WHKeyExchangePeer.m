//
//  WHKeyExchangePeer.m
//  whisper
//
//  Created by Thomas Goyne on 7/23/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHKeyExchangePeer.h"

#import "Contact.h"
#import "WHError.h"
#import "WHKeyPair.h"
#import "WHMultipeerBrowser.h"
#import "WHMultipeerSession.h"

@interface RACSignal (WHNext)
- (instancetype)next:(id (^)(id value))block;
@end

@implementation RACSignal (WHNext)
- (instancetype)next:(id (^)(id))block {
    Class class = self.class;
    __block BOOL first = YES;

    return [[self flattenMap:^RACStream *(id value) {
        if (first) {
            first = NO;
            id ret = block(value);
            if ([ret isKindOfClass:[NSError class]])
                return [class error:ret];
            return ret ? ret : [class empty];
        }

        return [class return:value];
    }] setNameWithFormat:@"[%@] -next:", self.name];
}
@end

@interface WHKeyExchangePeer ()
@property (nonatomic, strong) NSString *name;

@property (nonatomic, strong) MCPeerID *ownPeerID;
@property (nonatomic, strong) MCPeerID *remotePeerID;
@property (nonatomic, strong) NSString *peerJid;
@property (nonatomic, strong) WHMultipeerBrowser *browser;
@property (nonatomic, strong) invitationHandler invitation;
@end

@implementation WHKeyExchangePeer
- (instancetype)initWithOwnPeerID:(MCPeerID *)ownPeerID
                     remotePeerID:(MCPeerID *)remotePeerID
                          peerJid:(NSString *)peerJid
                          browser:(WHMultipeerBrowser *)browser
{
    if (!(self = [super init])) return self;
    self.name = remotePeerID.displayName;
    self.ownPeerID = ownPeerID;
    self.remotePeerID = remotePeerID;
    self.peerJid = peerJid;

    self.browser = browser;
    return self;
}

- (instancetype)initWithOwnPeerID:(MCPeerID *)ownPeerID
                     remotePeerID:(MCPeerID *)remotePeerID
                          peerJid:(NSString *)peerJid
                       invitation:(invitationHandler)invitation
{
    if (!(self = [super init])) return self;
    self.name = remotePeerID.displayName;
    self.ownPeerID = ownPeerID;
    self.remotePeerID = remotePeerID;
    self.peerJid = peerJid;

    self.invitation = invitation;
    return self;
}

- (RACSignal *)connectWithJid:(NSString *)jid {
    NSAssert(!!self.browser != !!self.invitation,
             @"WHKeyExchangePeer needs a service browser or invitation handler to connect");

    WHMultipeerSession *session;
    if (self.browser)
        session = [self.browser connectToPeer:self.remotePeerID ownJid:jid];
    else
        session = [[WHMultipeerSession alloc] initWithSelf:self.ownPeerID
                                                    remote:self.remotePeerID
                                                invitation:self.invitation];

    __block BOOL called = NO;
    WHKeyPair *newKP = [WHKeyPair createKeyPairForJid:self.peerJid];
    return [[[[[session.connected
            flattenMap:^RACStream *(NSNumber *didConnect) {
                assert(!called);
                called = YES;
                if (![didConnect boolValue]) {
                    [session disconnect];
                    return [WHError errorSignalWithDescription:@"Peer refused connection"];
                }
                NSError *error = [session sendData:[WHKeyPair getOwnGlobalKeyPair].publicKeyBits];
                return error ? [RACSignal error:error] : [session.incomingData take:3];
            }]
            next:^(NSData *globalKey) {
                [WHKeyPair addGlobalKey:globalKey fromJid:self.peerJid];
                return [session sendData:[WHKeyPair getOwnGlobalKeyPair].symmetricKey];
            }]
            next:^(NSData *symmetricKey) {
                [WHKeyPair addSymmetricKey:symmetricKey fromJid:self.peerJid];
                return [session sendData:newKP.publicKeyBits];
            }]
            deliverOn:[RACScheduler mainThreadScheduler]]
            next:^(NSData *publicKey) {
                [WHKeyPair addKey:publicKey fromJid:self.peerJid];
                [session disconnect];
                return [Contact createWithName:self.name jid:self.peerJid];
            }];
}

- (void)reject {
    NSAssert(self.invitation, @"Can only reject incoming connections");
    self.invitation(NO, nil);
    self.invitation = nil;
}
@end
