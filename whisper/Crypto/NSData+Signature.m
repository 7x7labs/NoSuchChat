//
//  NSData+Signature.m
//  whisper
//
//  Created by Thomas Goyne on 7/18/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "NSData+Signature.h"

#import <CommonCrypto/CommonDigest.h>

@implementation NSData (Signature)
- (NSData *)wh_sign:(SecKeyRef)key {
    size_t hashSize = SecKeyGetBlockSize(key);
    uint8_t *bytes = malloc(hashSize);

    OSStatus err = SecKeyRawSign(key,
                                 kSecPaddingPKCS1SHA256,
                                 [self bytes],
                                 [self length],
                                 bytes,
                                 &hashSize);
    NSAssert(err == errSecSuccess, @"SecKeyRawSign failed: %d", (int)err);

    return [NSData dataWithBytesNoCopy:bytes length:hashSize];
}

- (BOOL)wh_verifySignature:(NSData *)signature withKey:(SecKeyRef)key {
    return errSecSuccess == SecKeyRawVerify(key,
                                            kSecPaddingPKCS1SHA256,
                                            [self bytes],
                                            [self length],
                                            [signature bytes],
                                            [signature length]);
}
@end
