//
//  WHMultipeerManager.m
//  whisper
//
//  Created by Thomas Goyne on 9/9/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHMultipeerManager.h"

#import "WHMultipeerAdvertiser.h"
#import "WHMultipeerBrowser.h"
#import "WHMultipeerSession.h"
#import "WHKeyExchangePeer.h"

#import <libextobjc/EXTScope.h>

@interface WHMultipeerManager ()
@property (nonatomic, strong) NSArray *peers;
@property (nonatomic, strong) RACSignal *invitations;

@property (nonatomic, strong) NSString *jid;
@property (nonatomic, strong) NSString *displayName;

@property (nonatomic, strong) WHMultipeerAdvertiser *advertiser;
@property (nonatomic, strong) WHMultipeerBrowser *browser;
@property (nonatomic, strong) NSMutableDictionary *keyexPeers;
@end

@implementation WHMultipeerManager
- (instancetype)initWithJid:(NSString *)jid name:(NSString *)displayName {
    if (!(self = [super init])) return self;

    self.jid = jid;
    self.displayName = displayName;
    self.advertiser = [[WHMultipeerAdvertiser alloc] initWithJid:jid displayName:displayName];
    self.browser = [[WHMultipeerBrowser alloc] initWithDisplayName:displayName jid:jid];
    self.keyexPeers = [NSMutableDictionary new];

    RACSubject *invitations = [RACSubject subject];
    self.invitations = invitations;

    @weakify(self)
    RAC(self, peers) = [[[RACSignal merge:@[self.advertiser.incoming, self.browser.peers]]
                        flattenMap:^RACStream *(WHMultipeerSession *session) {
                            @strongify(self) // RACAble captures self even when observing something else
                            NSLog(@"Initiating session with %@ %@", session.peerJid, session.peerID);
                            return [RACAbleWithStart(session, connected) mapReplace:session];
                        }]
                        map:^(WHMultipeerSession *session) {
                            @strongify(self)

                            WHKeyExchangePeer *peer = self.keyexPeers[session.peerJid];
                            if (session.connected) {
                                NSLog(@"Session %@ with %@ connected", session.peerID, session.peerJid);
                                if (!peer) {
                                    peer = self.keyexPeers[session.peerJid] = [WHKeyExchangePeer new];

                                    @weakify(peer)
                                    [[RACAbleWithStart(peer, wantsToConnect)
                                     distinctUntilChanged]
                                     subscribeNext:^(NSNumber *wantsToConnect) {
                                         if ([wantsToConnect boolValue]) {
                                             @strongify(peer);
                                             [invitations sendNext:peer];
                                         }
                                     }];
                                }
                                [peer addSession:session];
                                peer.name = session.peerID.displayName;
                                peer.jid = session.peerJid;
                            }
                            else if (peer) {
                                NSLog(@"Session %@ with %@ disconnected", session.peerID, session.peerJid);
                                [peer removeSession:session];
                            }

                            return [[self.keyexPeers.rac_valueSequence
                                    filter:^BOOL(WHKeyExchangePeer *p) {
                                        return p.hasSessions;
                                    }]
                                    array];
                        }];

    [self.browser startBrowsing];
    RACBind(self.advertiser, advertising) = RACBind(self, advertising);

    return self;
}

@end
