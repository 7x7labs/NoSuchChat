//
//  WHXMPPWrapper.h
//  whisper
//
//  Created by Thomas Goyne on 7/16/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSignal;

@protocol WHXMPPStream <NSObject>
- (RACSignal *)connectToServer:(NSString *)server
                          port:(uint16_t)port
                      username:(NSString *)username
                      password:(NSString *)password;

- (RACSignal *)connectAndRegisterOnServer:(NSString *)server
                                     port:(uint16_t)port
                                 username:(NSString *)username
                                 password:(NSString *)password;

- (RACSignal *)sendMessage:(NSString *)body to:(NSString *)recipient;

@property (nonatomic, readonly) RACSignal *messages;
@end

@interface WHXMPPWrapper : NSObject <WHXMPPStream>

@end
