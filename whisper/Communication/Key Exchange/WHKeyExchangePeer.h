//
//  WHKeyExchangePeer.h
//  whisper
//
//  Created by Thomas Goyne on 7/23/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class RACSignal;
@class WHMultipeerBrowser;

typedef void (^invitationHandler)(BOOL accept, MCSession *session);

@interface WHKeyExchangePeer : NSObject
@property (nonatomic, readonly) NSString *name;

- (RACSignal *)connectWithJid:(NSString *)jid;
- (void)reject;

- (instancetype)initWithPeerID:(MCPeerID *)peerID
                       browser:(WHMultipeerBrowser *)browser;

- (instancetype)initWithPeerID:(MCPeerID *)peerID
                    invitation:(invitationHandler)invitation;
@end
