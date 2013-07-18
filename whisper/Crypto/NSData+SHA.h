//
//  NSData+SHA.h
//  whisper
//
//  Created by Thomas Goyne on 7/18/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (SHA)
- (NSData *)sha256;
@end
