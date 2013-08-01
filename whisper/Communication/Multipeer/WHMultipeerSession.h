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
- (instancetype)initWithPeer:(MCPeerID *)peer serviceBrowser:(MCNearbyServiceBrowser *)browser;
- (instancetype)initWithPeer:(MCPeerID *)peer invitation:(invitationHandler)invitation;

- (NSError *)sendData:(NSData *)data;

@property (nonatomic, readonly) RACSignal *connected;
@property (nonatomic, readonly) RACSignal *incomingData;
@end
