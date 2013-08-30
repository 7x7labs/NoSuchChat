//
//  WHContactListViewModel.h
//  whisper
//
//  Created by Thomas Goyne on 8/29/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class Contact;
@class WHChatClient;

@interface WHContactRowViewModel : NSObject
@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic, readonly) NSString *status;
@property (nonatomic, readonly) NSString *gravatarURL;
@end

@interface WHContactListViewModel : NSObject
@property (nonatomic, readonly) NSInteger count;

- (instancetype)initWithClient:(WHChatClient *)client;
- (WHContactRowViewModel *)objectAtIndexedSubscript:(NSUInteger)index;
- (Contact *)rawContactAtIndex:(NSUInteger)index;
- (void)deleteContactAtIndex:(NSUInteger)index;
@end
