//
//  WHWelcomeViewModel.h
//  whisper
//
//  Created by Thomas Goyne on 9/12/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class WHChatClient;

@interface WHWelcomeViewModel : NSObject
@property (nonatomic, readonly) BOOL isFirstRun;
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, readonly) BOOL canSave;
@property (nonatomic, readonly) NSString *disabledText;

- (instancetype)initWithClient:(WHChatClient *)client;
- (void)save;
@end
