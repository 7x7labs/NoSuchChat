//
//  WHKeyPair.m
//  whisper
//
//  Created by Thomas Goyne on 7/18/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHKeyPair.h"

#import "NSData+Encryption.h"

#if DEBUG // The tests take a few minutes with 4096 bit keys
#define kKeyBits @512
#else
#define kKeyBits @4096
#endif

static NSData *tag(NSString *jid, NSString *type) {
    return [[jid stringByAppendingString:type] dataUsingEncoding:NSUTF8StringEncoding];
}

static NSMutableDictionary *optCommon(NSString *jid, NSString *type, CFTypeRef key, id value) {
    NSMutableDictionary *opt = [NSMutableDictionary dictionary];
    opt[(__bridge id)kSecClass] = (__bridge id)kSecClassKey;
    opt[(__bridge id)kSecAttrApplicationTag] = tag(jid, type);
    if (key && value)
        opt[(__bridge id)key] = value;
    return opt;
}

static NSDictionary *symmetricDictionary(NSString *jid, NSString *type, CFTypeRef key, id value) {
    NSMutableDictionary *opt = optCommon(jid, type, key, value);
    opt[(__bridge id)kSecAttrKeyClass] = (__bridge id)kSecAttrKeyClassSymmetric;
    return opt;
}

static NSDictionary *rsaDictionary(NSString *jid, NSString *type, CFTypeRef key, id value) {
    NSMutableDictionary *opt = optCommon(jid, type, key, value);
    opt[(__bridge id)kSecAttrKeyType] = (__bridge id)kSecAttrKeyTypeRSA;
    return opt;
}

@interface WHKeyPair ()
@property (nonatomic, strong) NSData *publicKeyBits;
@property (nonatomic, strong) NSData *symmetricKey;
@end

@implementation WHKeyPair
- (void)dealloc {
    if (self.publicKey)  CFRelease(self.publicKey);
    if (self.privateKey) CFRelease(self.privateKey);
}

- (NSData *)getBits:(NSDictionary *)opt {
    CFDataRef bits = NULL;
    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)opt, (CFTypeRef *)&bits);
    if (err != errSecSuccess)
        NSLog(@"Failed getting bits: %d", (int)err);
    return (__bridge_transfer NSData *)bits;
}

+ (void)deleteKey:(NSDictionary *)opt {
    OSStatus err = SecItemDelete((__bridge CFDictionaryRef)opt);
    NSAssert(err == errSecSuccess || err == errSecItemNotFound,
             @"Failed to delete existing key: %d", (int)err);
}

- (void)getKey:(SecKeyRef *)key forJid:(NSString *)jid ofType:(NSString *)type {
    NSDictionary *opt = rsaDictionary(jid, type, kSecReturnRef, @YES);
    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)opt, (CFTypeRef *)key);
    if (err != errSecSuccess) {
        NSLog(@"Failed getting key: %d", (int)err);
        *key = NULL;
    }
}

- (void)getKeyBitsForJid:(NSString *)jid ofType:(NSString *)type {
    self.publicKeyBits = [self getBits:rsaDictionary(jid, type, kSecReturnData, @YES)];
}

- (void)getSymmetricKeyForJid:(NSString *)jid {
    self.symmetricKey = [self getBits:symmetricDictionary(jid, @"_sym", kSecReturnData, @YES)];
}

+ (void)deleteKeyForJid:(NSString *)jid ofType:(NSString *)type {
    [self deleteKey:rsaDictionary(jid, type, nil, nil)];
}

+ (WHKeyPair *)createKeyPairForJid:(NSString *)jid {
    [self deleteKeyForJid:jid ofType:@"_public"];
    [self deleteKeyForJid:jid ofType:@"_private"];

    NSDictionary *opt = @{
        (__bridge id)kSecAttrIsPermanent: @YES,
        (__bridge id)kSecAttrKeySizeInBits: kKeyBits,
        (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
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

+ (WHKeyPair *)createOwnGlobalKeyPair {
    WHKeyPair *kp = [self createKeyPairForJid:@"self"];
    kp.symmetricKey = [NSData wh_createSessionKey];
    [self addSymmetricKey:kp.symmetricKey fromJid:@"self"];
    return kp;
}

+ (WHKeyPair *)getOwnGlobalKeyPair {
    WHKeyPair *kp = [self getOwnKeyPairForJid:@"self"];
    if (kp)
        [kp getSymmetricKeyForJid:@"self"];
    else
        kp = [self createOwnGlobalKeyPair];
    return kp;
}

+ (WHKeyPair *)addKey:(NSData *)key fromJid:(NSString *)jid ofType:(NSString *)type {
    [self deleteKeyForJid:jid ofType:type];

    NSDictionary *opt = rsaDictionary(jid, type, kSecValueData, key);
    WHKeyPair *keyPair = [WHKeyPair new];
    OSStatus err = SecItemAdd((__bridge CFDictionaryRef)opt, (CFTypeRef *)&keyPair->_publicKey);
    NSAssert(err == errSecSuccess, @"Failed to add key to keychain: %d", (int)err);
    keyPair.publicKeyBits = key;
    return keyPair;
}

+ (WHKeyPair *)getKeyFromJid:(NSString *)jid ofType:(NSString *)type{
    WHKeyPair *keyPair = [WHKeyPair new];
    [keyPair getKey:&keyPair->_publicKey forJid:jid ofType:type];
    if (keyPair.publicKey) {
        [keyPair getKeyBitsForJid:jid ofType:type];
        return keyPair;
    }
    return nil;
}

+ (WHKeyPair *)addKey:(NSData *)key fromJid:(NSString *)jid {
    return [self addKey:key fromJid:jid ofType:@"_incoming"];
}

+ (WHKeyPair *)getKeyFromJid:(NSString *)jid {
    return [self getKeyFromJid:jid ofType:@"_incoming"];
}

+ (WHKeyPair *)addGlobalKey:(NSData *)key fromJid:(NSString *)jid {
    return [self addKey:key fromJid:jid ofType:@"_global"];
}

+ (WHKeyPair *)getGlobalKeyFromJid:(NSString *)jid {
    WHKeyPair *kp = [self getKeyFromJid:jid ofType:@"_global"];
    [kp getSymmetricKeyForJid:jid];
    return kp;
}

+ (void)addSymmetricKey:(NSData *)data fromJid:(NSString *)jid {
    [self deleteKey:symmetricDictionary(jid, @"_sym", nil, nil)];
    NSDictionary *opt = symmetricDictionary(jid, @"_sym", kSecValueData, data);
    OSStatus err = SecItemAdd((__bridge CFDictionaryRef)opt, NULL);
    NSAssert(err == errSecSuccess, @"Failed to add symmetric key to keychain: %d", (int)err);
}

@end
