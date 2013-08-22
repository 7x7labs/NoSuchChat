//
//  WHPeerList.h
//  whisper
//
//  Created by Thomas Goyne on 7/22/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@interface WHPeerList : NSObject
@property (nonatomic, readonly) NSArray *peers;

- (instancetype)initWithOwnPeerID:(MCPeerID *)peerID contactJids:(NSSet *)jids;
@end
