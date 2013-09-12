//
//  WHDiffieHellman.m
//  whisper
//
//  Created by Thomas Goyne on 8/26/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHDiffieHellman.h"

#import "NSData+Encryption.h"
#import "NSData+SHA.h"

#import <libkern/OSAtomic.h>

int curve25519_donna(uint8_t *, const uint8_t *, const uint8_t *);

@interface WHDiffieHellman ()
@property (nonatomic) int32_t ourKeyId;
@property (nonatomic) int32_t theirKeyId;
@property (nonatomic, strong) NSData *publicKey;
@property (nonatomic, strong) NSData *private;
@property (nonatomic, strong) NSData *shared;
@end

@implementation WHDiffieHellman
+ (WHDiffieHellman *)createOutgoing {
    WHDiffieHellman *dh = [self new];

    uint8_t publicBuff[32], privateBuff[32];

    // Magic numbers and stuff from http://cr.yp.to/ecdh.html
    SecRandomCopyBytes(kSecRandomDefault, 32, privateBuff);
    privateBuff[0] &= 248;
    privateBuff[31] &= 127;
    privateBuff[31] |= 64;

    static const uint8_t basepoint[32] = {9};
    curve25519_donna(publicBuff, privateBuff, basepoint);

    dh.private = [NSData dataWithBytes:privateBuff length:32];
    dh.publicKey = [NSData dataWithBytes:publicBuff length:32];

    static volatile int32_t keyId = 0;
    dh.ourKeyId = OSAtomicIncrement32(&keyId);

    return dh;
}

+ (WHDiffieHellman *)createIncomingWithKey:(NSData *)keyData keyId:(int32_t)keyId {
    WHDiffieHellman *dh = [self new];
    dh.publicKey = keyData;
    dh.theirKeyId = keyId;
    return dh;
}

- (WHDiffieHellman *)combineWith:(WHDiffieHellman *)other {
    WHDiffieHellman *combined = [WHDiffieHellman new];
    combined.ourKeyId = self.ourKeyId;
    combined.theirKeyId = other.theirKeyId;

    uint8_t secretBuff[32];
    curve25519_donna(secretBuff, [self.private bytes], [other.publicKey bytes]);
    combined.shared = [NSData dataWithBytes:secretBuff length:32];

    return combined;
}

- (NSData *)encrypt:(NSData *)data iterations:(uint32_t)iterations {
    if (!self.shared) return data;
    NSData *key = self.shared;
    while (iterations-- != 0)
        key = [key sha256];
    return [data wh_AES256EncryptWithKey:key];
}

- (NSData *)decrypt:(NSData *)data iterations:(uint32_t)iterations {
    if (!self.shared) return data;
    NSData *key = self.shared;
    while (iterations-- != 0)
        key = [key sha256];
    return [data wh_AES256DecryptWithKey:key];
}
@end
