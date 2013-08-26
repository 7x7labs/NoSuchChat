//
//  WHMultipeerSession.h
//  whisper
//
//  Created by Thomas Goyne on 7/31/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class RACSignal;

typedef void (^invitationHandler)(BOOL accept, MCSession *session);

@interface WHMultipeerSession : NSObject
- (instancetype)initWithRemotePeerID:(MCPeerID *)remotePeer
                              ownJid:(NSString *)ownJid
                      serviceBrowser:(MCNearbyServiceBrowser *)browser;
- (instancetype)initWithSelf:(MCPeerID *)ownPeer
                      remote:(MCPeerID *)remotePeer
                  invitation:(invitationHandler)invitation;

- (NSError *)sendData:(NSData *)data;
- (NSData *)read;

- (void)disconnect;
- (void)cancel;

@property (nonatomic, readonly) RACSignal *connected;
@property (nonatomic, readonly) BOOL cancelled;
@end
