//
//  WHMultipeerAdvertiser.h
//  whisper
//
//  Created by Thomas Goyne on 7/31/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@interface WHMultipeerAdvertiser : NSObject
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic) BOOL advertising;

@property (nonatomic, readonly) MCPeerID *peerID;
@property (nonatomic, readonly) RACSignal *invitations;

- (instancetype)initWithJid:(NSString *)jid;
@end
