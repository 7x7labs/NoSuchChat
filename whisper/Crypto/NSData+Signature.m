//
//  NSData+Signature.m
//  whisper
//
//  Created by Thomas Goyne on 7/18/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "NSData+Signature.h"

#import <CommonCrypto/CommonDigest.h>
#import <EXTScope.h>

@implementation NSData (Signature)
- (NSData *)wh_sign:(SecKeyRef)key {
	size_t hashSize = SecKeyGetBlockSize(key);
    uint8_t *bytes = malloc(hashSize);
    @onExit { free(bytes); };

	SecKeyRawSign(key,
                  kSecPaddingPKCS1SHA256,
                  [self bytes],
                  [self length],
                  bytes,
                  &hashSize);

    return [NSData dataWithBytes:bytes length:hashSize];
}

- (BOOL)wh_verify:(SecKeyRef)key {
    if ([self length] < CC_SHA256_DIGEST_LENGTH) return NO;
    return noErr == SecKeyRawVerify(key,
                                    kSecPaddingPKCS1SHA256,
                                    [self bytes],
                                    CC_SHA256_DIGEST_LENGTH,
                                    [self bytes] + CC_SHA256_DIGEST_LENGTH,
                                    [self length] - CC_SHA256_DIGEST_LENGTH);
}
@end
