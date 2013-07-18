//
//  NSData+Compression.h
//  whisper
//
//  Created by Thomas Goyne on 7/19/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (Compression)
- (NSData *)wh_compress;
- (NSData *)wh_decompress;
@end
