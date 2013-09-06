//
//  WHAlert.h
//  whisper
//
//  Created by Thomas Goyne on 8/2/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@interface WHAlert : NSObject
+ (void)alertWithError:(NSError *)error;
+ (RACSignal *)alertWithMessage:(NSString *)message title:(NSString *)title buttons:(NSArray *)buttons;
@end
