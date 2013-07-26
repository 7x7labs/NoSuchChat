//
//  WHSettingsViewModel.h
//  whisper
//
//  Created by Thomas Goyne on 7/26/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class WHChatClient;

@interface WHSettingsViewModel : NSObject
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic) BOOL valid;

- (instancetype)initWithClient:(WHChatClient *)client;
- (void)save;
@end
