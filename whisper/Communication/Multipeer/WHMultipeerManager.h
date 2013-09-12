//
//  WHMultipeerManager.h
//  whisper
//
//  Created by Thomas Goyne on 9/9/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@interface WHMultipeerManager : NSObject
@property (nonatomic, readonly) NSArray *peers;
@property (nonatomic, readonly) RACSignal *invitations;
@property (nonatomic) BOOL advertising;

- (instancetype)initWithJid:(NSString *)jid name:(NSString *)displayName;
@end
