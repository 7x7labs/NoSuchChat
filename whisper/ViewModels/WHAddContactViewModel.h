//
//  WHAddContactViewModel.h
//  whisper
//
//  Created by Thomas Goyne on 9/4/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class WHChatClient;
@class WHKeyExchangePeer;

@interface WHPotentialContactViewModel : NSObject
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) UIImage *avatar;
@property (nonatomic, readonly) BOOL connecting;

- (RACSignal *)connect;
@end

@interface WHAddContactViewModel : NSObject
@property (nonatomic, readonly) NSInteger count;
@property (nonatomic, readonly) BOOL advertising;
@property (nonatomic, readonly) RACSignal *invitations;

- (instancetype)initWithClient:(WHChatClient *)client;
- (WHPotentialContactViewModel *)objectAtIndexedSubscript:(NSUInteger)index;
- (WHPotentialContactViewModel *)viewModelForPeer:(WHKeyExchangePeer *)peer;
@end
