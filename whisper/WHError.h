//
//  WHError.h
//  whisper
//
//  Created by Thomas Goyne on 8/2/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class RACSignal;

@interface WHError : NSError
+ (WHError *)errorWithDescription:(NSString *)description;
+ (RACSignal *)errorSignalWithDescription:(NSString *)description;
@end
