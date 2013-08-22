//
//  WHKeyExchangePeer.h
//  whisper
//
//  Created by Thomas Goyne on 7/23/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class WHMultipeerBrowser;

typedef void (^invitationHandler)(BOOL accept, MCSession *session);

@interface WHKeyExchangePeer : NSObject
@property (nonatomic, readonly) NSString *name;

- (RACSignal *)connectWithJid:(NSString *)jid;
- (void)reject;

- (instancetype)initWithOwnPeerID:(MCPeerID *)ownPeerID
                     remotePeerID:(MCPeerID *)remotePeerID
                          peerJid:(NSString *)peerJid
                          browser:(WHMultipeerBrowser *)browser;

- (instancetype)initWithOwnPeerID:(MCPeerID *)ownPeerID
                     remotePeerID:(MCPeerID *)remotePeerID
                          peerJid:(NSString *)peerJid
                    invitation:(invitationHandler)invitation;
@end
