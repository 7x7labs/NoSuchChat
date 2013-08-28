//
//  Message.h
//  whisper
//
//  Created by Thomas Goyne on 7/16/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "_Message.h"

@interface Message : _Message
+ (RACSignal *)deleteOlderThan:(NSDate *)date;
- (RACSignal *)delete;
@end
