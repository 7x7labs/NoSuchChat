//
//  WHError.h
//  whisper
//
//  Created by Thomas Goyne on 8/2/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@interface WHError : NSError
+ (WHError *)errorWithDescription:(NSString *)description;
@end
