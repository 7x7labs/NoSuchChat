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

static NSMutableDictionary *activeSessions() {
    static NSMutableDictionary *sessions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sessions = [NSMutableDictionary new]; });
    return sessions;
}

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

    NSLog(@"%p: Beginning key exchange with %@", self, jid);

    WHKeyPair *newKP;
    WHMultipeerSession *session;
    @synchronized (activeSessions()) {
        WHMultipeerSession *existingSession = activeSessions()[self.peerJid];
        if (existingSession) {
            NSLog(@"%p: session already exists", self);
            // We can't just always use the existing session, because the
            // sessions may have been created in different order on each device,
            // so we could end up with both sessions being cancelled.
            // To work around this, we reject or cancel the connection initiated
            // by the peer with the greater JID, even if this means throwing
            // away the further-progressed one.
            NSComparisonResult order = [self.peerJid compare:jid];
            if (self.invitation) {
                if (order == NSOrderedDescending) {
                    NSLog(@"%p: Rejecting invitation from greater jid", self);
                    self.invitation(NO, nil);
                    return [RACSignal empty];
                }
            }
            else if (order == NSOrderedAscending) {
                NSLog(@"%p: Not initiating outgoing connection", self);
                return [RACSignal empty];
            }

            [existingSession cancel];
        }
        else {
            NSLog(@"%p: no existing connection", self);
        }

        if (self.browser)
            session = [self.browser connectToPeer:self.remotePeerID ownJid:jid];
        else
            session = [[WHMultipeerSession alloc] initWithSelf:self.ownPeerID
                                                        remote:self.remotePeerID
                                                    invitation:self.invitation];

        activeSessions()[self.peerJid] = session;
        NSLog(@"%p: created session", self);

        // Create the keypair within the synchronized block to avoid a crazy
        // race condition where a session is cancelled immediately before the
        // keypair is created, and then that thread doesn't run until after the
        // surviving session has created its keypair.
        newKP = [WHKeyPair createKeyPairForJid:self.peerJid];
        NSLog(@"%p: created key", self);
    }

    return [[[session.connected
        deliverOn:[RACScheduler schedulerWithPriority:RACSchedulerPriorityDefault
                                                 name:@"Key exchange data reading"]]
        flattenMap:^RACStream *(NSNumber *didConnect) {
            if (![didConnect boolValue]) {
                [self endSession:session];
                if (session.cancelled) {
                    NSLog(@"%p: connection was cancelled", self);
                    return [RACSignal empty];
                }
                else {
                    NSLog(@"%p: failed to connect", self);
                    NSString *message = [NSString stringWithFormat:@"\"%@\" canceled the connection.", self.remotePeerID.displayName];
                    return [WHError errorSignalWithDescription:message];
                }
            }

            WHDiffieHellman *dh = [WHDiffieHellman new];

            #define SEND(data_expr) \
                do { \
                    NSData *data = data_expr; \
                    data = [dh encrypt:data]; \
                    NSError *error; \
                    if ((error = [session sendData:data])) {\
                        [self endSession:session]; \
                        return [RACSignal error:error]; \
                    } \
                } while (0)

            #define RECV(expr) \
                do { \
                    NSData *data = [session read]; \
                    if (!data) {\
                        [self endSession:session]; \
                        return [RACSignal empty]; \
                    } \
                    data = [dh decrypt:data]; \
                    expr; \
                } while (0)

            NSLog(@"%p: Exchanging D-H keys", self);
            SEND(dh.publicKey);
            RECV([dh setOtherPublic:data]);

            NSLog(@"%p: Exchanging global public", self);
            SEND([WHKeyPair getOwnGlobalKeyPair].publicKeyBits);
            RECV([WHKeyPair addGlobalKey:data fromJid:self.peerJid]);

            NSLog(@"%p: Exchanging global symmetric keys", self);
            SEND([WHKeyPair getOwnGlobalKeyPair].symmetricKey);
            RECV([WHKeyPair addSymmetricKey:data fromJid:self.peerJid]);

            NSLog(@"%p: Exchanging per-peer public keys", self);
            SEND(newKP.publicKeyBits);
            RECV([WHKeyPair addKey:data fromJid:self.peerJid]);

            // Send a dummy packet to ensure that we don't close the socket
            // before our last data actually gets sent
            SEND([NSData data]);
            (void)[session read];

            [self endSession:session];

            NSLog(@"%p: Creating contact", self);
            return [Contact createWithName:self.name jid:self.peerJid];
        }]
        replayLast];
}

- (void)endSession:(WHMultipeerSession *)session {
    NSLog(@"%p: Disconnecting from multipeer session", self);
    [session disconnect];
    @synchronized(activeSessions()) {
        [activeSessions() removeObjectForKey:self.peerJid];
    }
}

// Used purely by unit tests to clean up
+ (void)cancelAll {
    @synchronized(activeSessions()) {
        for (WHMultipeerSession *session in [activeSessions() allValues])
            [session cancel];
        [activeSessions() removeAllObjects];
    }
}

- (void)reject {
    NSAssert(self.invitation, @"Can only reject incoming connections");
    self.invitation(NO, nil);
    self.invitation = nil;
}
@end
