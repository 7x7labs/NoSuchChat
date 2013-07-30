//
//  NSData+Encryption.m
//  whisper
//
//  Created by Thomas Goyne on 7/20/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "NSData+Encryption.h"

#import <CommonCrypto/CommonCryptor.h>

@implementation NSData (Encryption)
+ (NSData *)wh_createSessionKey {
    NSMutableData *data = [NSMutableData dataWithLength:kCCKeySizeAES256];
    OSStatus err = SecRandomCopyBytes(kSecRandomDefault, kCCKeySizeAES256, [data mutableBytes]);
    NSAssert(err == noErr, @"Error getting random bytes for session key: %d", (int)err);
    return data;
}

- (NSData *)wh_DoEnryptOrDecrypt:(CCOperation)operation withKey:(NSData *)key {
    if ([key length] != kCCKeySizeAES256) {
        NSLog(@"Bad key length for AES-256: %u", (unsigned)[key length]);
        return nil;
    }

    NSMutableData *encrypted = [NSMutableData dataWithLength:[self length] + kCCBlockSizeAES128];

    size_t bytesEncrypted = 0;
    CCCryptorStatus err = CCCrypt(operation, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                  [key bytes], kCCKeySizeAES256,
                                  NULL,
                                  [self bytes], [self length],
                                  [encrypted mutableBytes], [encrypted length],
                                  &bytesEncrypted);

    NSAssert(err == kCCSuccess, @"CCCrypt failed: %d", (int)err);

    encrypted.length = bytesEncrypted;
    return encrypted;
}

- (NSData *)wh_AES256EncryptWithKey:(NSData *)key {
    return [self wh_DoEnryptOrDecrypt:kCCEncrypt withKey:key];
}

- (NSData *)wh_AES256DecryptWithKey:(NSData *)key {
    return [self wh_DoEnryptOrDecrypt:kCCDecrypt withKey:key];
}

- (NSData *)wh_encryptWithKey:(SecKeyRef)key {
    NSMutableData *data = [NSMutableData dataWithLength:SecKeyGetBlockSize(key)];
    size_t size = [data length];

    OSStatus err = SecKeyEncrypt(key,
                                 kSecPaddingNone,
                                 [self bytes], [self length],
                                 [data mutableBytes], &size
                                 );
    NSAssert(err == errSecSuccess, @"SecKeyEncrypt failed: %d", (int)err);
    data.length = size;
    return data;
}

- (NSData *)wh_decryptWithKey:(SecKeyRef)key {
    NSMutableData *data = [NSMutableData dataWithLength:SecKeyGetBlockSize(key)];
    size_t size = [data length];

    OSStatus err = SecKeyDecrypt(key,
                                 kSecPaddingNone,
                                 [self bytes], [self length],
                                 [data mutableBytes], &size
                                 );
    NSAssert(err == errSecSuccess, @"SecKeyDecrypt failed: %d", (int)err);
    data.length = size;
    return data;
}
@end
