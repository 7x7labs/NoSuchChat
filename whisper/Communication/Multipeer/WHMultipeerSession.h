//
//  WHMultipeerSession.h
//  whisper
//
//  Created by Thomas Goyne on 7/31/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class RACSignal;
@class WHMultipeerConnection;

typedef void (^invitationHandler)(BOOL accept, MCSession *session);
typedef enum WHPacketMessage : int32_t WHPacketMessage;

@interface WHMultipeerSession : NSObject
@property (nonatomic, readonly) NSString *peerJid;
@property (nonatomic, readonly) MCPeerID *peerID;
@property (nonatomic, readonly) BOOL connected;
@property (nonatomic, readonly) RACSignal *incomingData;

- (instancetype)initWithRemotePeerID:(MCPeerID *)remotePeer
                             peerJid:(NSString *)peerJid
                              ownJid:(NSString *)ownJid
                      serviceBrowser:(MCNearbyServiceBrowser *)browser;

- (instancetype)initWithSelf:(MCPeerID *)ownPeer
                      remote:(MCPeerID *)remotePeer
                     peerJid:(NSString *)ownJid
                  invitation:(invitationHandler)invitation;

- (NSError *)sendData:(NSData *)data;
@end
