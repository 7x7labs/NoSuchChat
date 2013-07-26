//
//  WHKeyPair.m
//  whisper
//
//  Created by Thomas Goyne on 7/18/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHKeyPair.h"

#if DEBUG // The tests take a few minutes with 4096 bit keys
#define kKeyBits @512
#else
#define kKeyBits @4096
#endif

static NSData *tag(NSString *jid, NSString *type) {
    return [[jid stringByAppendingString:type] dataUsingEncoding:NSUTF8StringEncoding];
}

@interface WHKeyPair ()
@property (nonatomic, strong) NSData *publicKeyBits;
@end

@implementation WHKeyPair
- (void)dealloc {
    if (self.publicKey)  CFRelease(self.publicKey);
    if (self.privateKey) CFRelease(self.privateKey);
}

- (void)getKey:(SecKeyRef *)key forJid:(NSString *)jid ofType:(NSString *)type {
    NSDictionary *opt = @{
                          (__bridge id)kSecClass: (__bridge id)kSecClassKey,
                          (__bridge id)kSecAttrApplicationTag: tag(jid, type),
                          (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
                          (__bridge id)kSecReturnRef: @YES,
                          };

    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)opt, (CFTypeRef *)key);
    if (err != errSecSuccess) {
        NSLog(@"Failed getting key: %d", (int)err);
        *key = NULL;
    }
}

- (void)getKeyBitsForJid:(NSString *)jid ofType:(NSString *)type {
    NSDictionary *opt = @{
                          (__bridge id)kSecClass: (__bridge id)kSecClassKey,
                          (__bridge id)kSecAttrApplicationTag: tag(jid, type),
                          (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
                          (__bridge id)kSecReturnData: @YES,
                          };

    CFDataRef bits;
    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)opt, (CFTypeRef *)&bits);
    self.publicKeyBits = (__bridge_transfer NSData *)bits;
    if (err != errSecSuccess) {
        NSLog(@"Failed getting bits: %d", (int)err);
        self.publicKeyBits = nil;
    }
}

+ (OSStatus)deleteKeyForJid:(NSString *)jid ofType:(NSString *)type {
    return SecItemDelete((__bridge CFDictionaryRef)@{(__bridge id)kSecClass: (__bridge id)kSecClassKey,
                          (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
                          (__bridge id)kSecAttrApplicationTag: tag(jid, type),
                          });
}

+ (WHKeyPair *)createKeyPairForJid:(NSString *)jid {
    [self deleteKeyForJid:jid ofType:@"_public"];
    [self deleteKeyForJid:jid ofType:@"_private"];

    NSDictionary *opt = @{
        (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
        (__bridge id)kSecAttrKeySizeInBits: kKeyBits,
        (__bridge id)kSecAttrIsPermanent: @YES,
        (__bridge id)kSecPrivateKeyAttrs: @{(__bridge id)kSecAttrApplicationTag:tag(jid, @"_private")},
        (__bridge id)kSecPublicKeyAttrs: @{(__bridge id)kSecAttrApplicationTag:tag(jid, @"_public")},
    };

    WHKeyPair *keyPair = [WHKeyPair new];
    OSStatus err = SecKeyGeneratePair((__bridge CFDictionaryRef)opt, &keyPair->_publicKey, &keyPair->_privateKey);
    NSAssert(err == errSecSuccess, @"SecKeyGeneratePair failed: %d", (int)err);
    [keyPair getKeyBitsForJid:jid ofType:@"_public"];
    return keyPair;
}

+ (WHKeyPair *)getOwnKeyPairForJid:(NSString *)jid {
    WHKeyPair *keyPair = [WHKeyPair new];
    [keyPair getKey:&keyPair->_publicKey forJid:jid ofType:@"_public"];
    [keyPair getKey:&keyPair->_privateKey forJid:jid ofType:@"_private"];
    if (keyPair.publicKey && keyPair.privateKey) {
        [keyPair getKeyBitsForJid:jid ofType:@"_public"];
        return keyPair;
    }
    return nil;
}

+ (WHKeyPair *)addKey:(NSData *)key fromJid:(NSString *)jid {
    [self deleteKeyForJid:jid ofType:@"_incoming"];

    NSDictionary *opt = @{(__bridge id)kSecClass: (__bridge id)kSecClassKey,
                          (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
                          (__bridge id)kSecAttrApplicationTag: tag(jid, @"_incoming"),
                          (__bridge id)kSecValueData: key,
                          };


    WHKeyPair *keyPair = [WHKeyPair new];
	OSStatus err = SecItemAdd((__bridge CFDictionaryRef)opt, (CFTypeRef *)&keyPair->_publicKey);
    NSAssert(err == errSecSuccess, @"Failed to add key to keychain: %d", (int)err);
    keyPair.publicKeyBits = key;
    return keyPair;
}

+ (WHKeyPair *)getKeyFromJid:(NSString *)jid {
    WHKeyPair *keyPair = [WHKeyPair new];
    [keyPair getKey:&keyPair->_publicKey forJid:jid ofType:@"_incoming"];
    if (keyPair.publicKey) {
        [keyPair getKeyBitsForJid:jid ofType:@"_incoming"];
        return keyPair;
    }
    return nil;
}

@end
