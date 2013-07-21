//
//  NSData+SHA.m
//  whisper
//
//  Created by Thomas Goyne on 7/18/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "NSData+SHA.h"

#import <CommonCrypto/CommonDigest.h>

@implementation NSData (SHA)
- (NSData *)sha256 {
    uint8_t *bytes = malloc(CC_SHA256_DIGEST_LENGTH);
    CC_SHA256([self bytes], [self length], bytes);
    return [NSData dataWithBytesNoCopy:bytes length:CC_SHA256_DIGEST_LENGTH];
}
@end
