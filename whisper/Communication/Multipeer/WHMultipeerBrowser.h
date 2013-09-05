//
//  WHMultipeerBrowser.h
//  whisper
//
//  Created by Thomas Goyne on 7/31/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@class WHMultipeerSession;

@interface WHMultipeerBrowser : NSObject
- (instancetype)initWithPeer:(MCPeerID *)peerID jid:(NSString *)ownJid;
- (void)startBrowsing;

@property (nonatomic, readonly) RACSignal *peers;
@end
