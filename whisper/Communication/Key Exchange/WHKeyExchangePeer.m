//
//  WHKeyExchangePeer.m
//  whisper
//
//  Created by Thomas Goyne on 7/23/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHKeyExchangePeer.h"

#import "Contact.h"
#import "WHDiffieHellman.h"
#import "WHError.h"
#import "WHKeyPair.h"
#import "WHMultipeerBrowser.h"
#import "WHMultipeerSession.h"

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

    WHKeyPair *newKP = [WHKeyPair createKeyPairForJid:self.peerJid];
    return [[session.connected
        deliverOn:[RACScheduler schedulerWithPriority:RACSchedulerPriorityDefault name:@"Key exchange data reading"]]
        flattenMap:^RACStream *(NSNumber *didConnect) {
            if (![didConnect boolValue]) {
                [session disconnect];
                return [WHError errorSignalWithDescription:@"Peer refused connection"];
            }

            WHDiffieHellman *dh = [WHDiffieHellman new];

            #define SEND(data_expr) \
                do { \
                    NSData *data = data_expr; \
                    data = [dh encrypt:data]; \
                    NSError *error; \
                    if ((error = [session sendData:data])) \
                        return [RACSignal error:error]; \
                } while (0)

            #define RECV(expr) \
                do { \
                    NSData *data = [session read]; \
                    if (!data) \
                        return [RACSignal empty]; \
                    data = [dh decrypt:data]; \
                    expr; \
                } while (0)

            SEND(dh.publicKey);
            RECV([dh setOtherPublic:data]);

            SEND([WHKeyPair getOwnGlobalKeyPair].publicKeyBits);
            RECV([WHKeyPair addGlobalKey:data fromJid:self.peerJid]);

            SEND([WHKeyPair getOwnGlobalKeyPair].symmetricKey);
            RECV([WHKeyPair addSymmetricKey:data fromJid:self.peerJid]);

            SEND(newKP.publicKeyBits);
            RECV([WHKeyPair addKey:data fromJid:self.peerJid]);

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
