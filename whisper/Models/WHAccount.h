//
//  WHAccount.h
//  whisper
//
//  Created by Thomas Goyne on 7/17/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class WHKeyPair;

@interface WHAccount : NSObject
@property (nonatomic, strong, readonly) NSString *jid;
@property (nonatomic, strong, readonly) NSString *password;

/// Get the Whisper account for this device, creating it if needed.
+ (WHAccount *)get;
+ (void)delete;
@end
