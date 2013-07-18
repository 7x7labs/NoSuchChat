//
//  NSData+SHA.m
//  whisper
//
//  Created by Thomas Goyne on 7/18/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "NSData+SHA.h"

#import <CommonCrypto/CommonDigest.h>
#import <EXTScope.h>

@implementation NSData (SHA)
- (NSData *)sha256 {
	CC_SHA256_CTX ctx;
    uint8_t *bytes = malloc(CC_SHA256_DIGEST_LENGTH);
    @onExit { free(bytes); };

    CC_SHA224_Init(&ctx);
    CC_SHA224_Update(&ctx, [self bytes], [self length]);
    CC_SHA224_Final(bytes, &ctx);

    return [NSData dataWithBytes:bytes length:CC_SHA224_DIGEST_LENGTH];
}
@end
