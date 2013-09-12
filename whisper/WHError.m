//
//  WHError.m
//  whisper
//
//  Created by Thomas Goyne on 8/2/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHError.h"

@implementation WHError
+ (WHError *)errorWithDescription:(NSString *)description {
    return [self errorWithDomain:@"com.7x7-labs.whisper"
                            code:0
                        userInfo:@{NSLocalizedDescriptionKey: description}];
}
@end
