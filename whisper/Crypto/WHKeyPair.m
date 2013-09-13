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
#define kKeyBits @2048
#endif

#define KEY_LOGGING 0

static void listKeys(NSString *message) {
#if KEY_LOGGING
    NSLog(@"%@", message);
    NSLog(@"------- Keychain Items ----------");
    NSMutableDictionary *query = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                  (__bridge id)kCFBooleanTrue, (__bridge id)kSecReturnAttributes,
                                  (__bridge id)kSecMatchLimitAll, (__bridge id)kSecMatchLimit,
                                  (__bridge id)kSecClassKey, (__bridge id)kSecClass,
                                  nil];

    CFTypeRef result = NULL;
    SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    NSArray *items = (__bridge_transfer id)result;

    for (NSDictionary *key in items) {
        NSString *tag = [[NSString alloc] initWithData:key[@"atag"] encoding:NSUTF8StringEncoding];

        NSMutableDictionary *opt = [@{(__bridge id)kSecClass: (__bridge id)kSecClassKey,
                                      (__bridge id)kSecAttrApplicationTag: key[@"atag"],
                                      (__bridge id)kSecReturnData: @YES,
                                      } mutableCopy];
        CFDataRef bits = NULL;
        OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)opt, (CFTypeRef *)&bits);
        if (err != errSecSuccess)
            NSLog(@"Failed getting bits: %d", (int)err);
        NSData *data = (__bridge_transfer NSData *)bits;
        NSUInteger bitLength = [data length];
        if (!bitLength) {
            NSLog(@"%@: could not read bits", tag);
            continue;
        }

        opt[(__bridge id)kSecReturnData] = @NO;
        opt[(__bridge id)kSecReturnRef] = @YES;

        SecKeyRef keyRef = NULL;
        err = SecItemCopyMatching((__bridge CFDictionaryRef)opt, (CFTypeRef *)&keyRef);
        if (err != errSecSuccess)
            NSLog(@"Failed getting key: %d", (int)err);

        NSLog(@"%@:%@%@",
              tag,
              bitLength ? [NSString stringWithFormat:@" bits (%d)", (int)bitLength] : @"",
              keyRef ? @" key" : @"");
    }
    NSLog(@"------- End Keychain Items ----------");
#endif
}

static NSData *tag(NSString *jid, NSString *type) {
    return [[jid stringByAppendingString:type] dataUsingEncoding:NSUTF8StringEncoding];
}

static NSMutableDictionary *optCommon(NSString *jid, NSString *type, CFTypeRef key, id value) {
    NSMutableDictionary *opt = [NSMutableDictionary dictionary];
    opt[(__bridge id)kSecClass] = (__bridge id)kSecClassKey;
    opt[(__bridge id)kSecAttrApplicationTag] = tag(jid, type);
    opt[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAlwaysThisDeviceOnly;
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
    listKeys(@"Pre-delete");
    [(NSMutableDictionary *)opt removeObjectForKey:(__bridge id)kSecAttrAccessible];

    OSStatus err = SecItemDelete((__bridge CFDictionaryRef)opt);
    NSAssert(err == errSecSuccess || err == errSecItemNotFound,
             @"Failed to delete existing key: %d", (int)err);

    listKeys(@"Post-delete");
}

- (void)getKey:(SecKeyRef *)key forJid:(NSString *)jid ofType:(NSString *)type {
    if (![[self getBits:rsaDictionary(jid, type, kSecReturnData, @YES)] length]) {
        NSLog(@"Got no data when reading key %@%@", jid, type);
        return;
    }

    NSDictionary *opt = rsaDictionary(jid, type, kSecReturnRef, @YES);
    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)opt, (CFTypeRef *)key);
    if (err != errSecSuccess) {
        NSLog(@"Failed getting key %@%@: %d", jid, type, (int)err);
        *key = NULL;
    }
    else if (!*key) {
        NSLog(@"Did not get %@ for %@", type, jid);
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
    WHKeyPair *keyPair = [WHKeyPair getOwnKeyPairForJid:jid];
    if (keyPair) return keyPair;

    NSDictionary *opt = @{
        (__bridge id)kSecAttrIsPermanent: @YES,
        (__bridge id)kSecAttrKeySizeInBits: kKeyBits,
        (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
        (__bridge id)kSecPrivateKeyAttrs: @{(__bridge id)kSecAttrApplicationTag:tag(jid, @"_private")},
        (__bridge id)kSecPublicKeyAttrs: @{(__bridge id)kSecAttrApplicationTag:tag(jid, @"_public")},
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAlwaysThisDeviceOnly
    };

    keyPair = [WHKeyPair new];
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
    static WHKeyPair *kp;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kp = [self getOwnKeyPairForJid:@"self"];
        if (kp)
            [kp getSymmetricKeyForJid:@"self"];
        else
            kp = [self createOwnGlobalKeyPair];
    });
    return kp;
}

+ (WHKeyPair *)addKey:(NSData *)key fromJid:(NSString *)jid ofType:(NSString *)type {
    if (![key length]) {
        NSLog(@"Trying to add invalid key for %@%@", jid, type);
        [NSException raise:@"com.7x7labs.whisper.badkey" format:@"Cannot add empty key for %@%@", jid, type];
    }
    [self deleteKeyForJid:jid ofType:type];

    listKeys([NSString stringWithFormat:@"Adding key %@%@", jid, type]);

    NSDictionary *opt = rsaDictionary(jid, type, kSecValueData, key);
    ((NSMutableDictionary *)opt)[(__bridge id)kSecAttrKeyClass] = (__bridge id)kSecAttrKeyClassPublic;
#if KEY_LOGGING
    NSLog(@"%@", opt);
#endif
    WHKeyPair *keyPair = [WHKeyPair new];
    OSStatus err = SecItemAdd((__bridge CFDictionaryRef)opt, NULL);
    NSAssert(err == errSecSuccess, @"Failed to add key to keychain: %d", (int)err);
    keyPair.publicKeyBits = key;

    listKeys(@"Added");

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
    listKeys(@"Get global key");
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

+ (void)deleteKeysForJid:(NSString *)jid {
    NSArray *types = @[@"_incoming", @"_global", @"_public", @"_private", @"_sym"];
    for (NSString *type in types)
        [self deleteKeyForJid:jid ofType:type];
}

+ (void)deleteAll {
    listKeys(@"Before deleteAll");

    NSDictionary *query = @{(__bridge id)kSecClass: (__bridge id)kSecClassKey};
    OSStatus err = SecItemDelete((__bridge CFDictionaryRef)query);
    if (err != errSecSuccess)
        NSLog(@"Failed deleting keys: %d", (int)err);

    listKeys(@"After deleteAll");
}
@end
