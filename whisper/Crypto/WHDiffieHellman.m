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

int curve25519_donna(uint8_t *, const uint8_t *, const uint8_t *);

// Create an IV for continued CBC over multiple calls from the ciphertext
static NSData *cbcIv(NSData *data) {
    return [data subdataWithRange:NSMakeRange([data length] - 16, 16)];
}

@interface WHDiffieHellman ()
@property (nonatomic, strong) NSData *publicKey;
@property (nonatomic, strong) NSData *private;
@property (nonatomic, strong) NSData *shared;
@property (nonatomic, strong) NSData *encryptIV;
@property (nonatomic, strong) NSData *decryptIV;
@end

@implementation WHDiffieHellman
- (instancetype)init {
    if (!(self = [super init])) return self;

    uint8_t publicBuff[32], privateBuff[32];

    // Magic numbers and stuff from http://cr.yp.to/ecdh.html
    SecRandomCopyBytes(kSecRandomDefault, 32, privateBuff);
    privateBuff[0] &= 248;
    privateBuff[31] &= 127;
    privateBuff[31] |= 64;

    static const uint8_t basepoint[32] = {9};
    curve25519_donna(publicBuff, privateBuff, basepoint);

    self.private = [NSData dataWithBytes:privateBuff length:32];
    self.publicKey = [NSData dataWithBytes:publicBuff length:32];

    return self;
}

- (void)setOtherPublic:(NSData *)otherPublic {
    uint8_t secretBuff[32];
    curve25519_donna(secretBuff, [self.private bytes], [otherPublic bytes]);
    self.shared = [NSData dataWithBytes:secretBuff length:32];
    self.private = nil;
}

- (NSData *)encrypt:(NSData *)data {
    if (!self.shared) return data;
    data = [data wh_AES256EncryptWithKey:self.shared iv:self.encryptIV];
    self.encryptIV = cbcIv(data);
    return data;
}

- (NSData *)decrypt:(NSData *)data {
    if (!self.shared) return data;
    NSData *decrypted = [data wh_AES256DecryptWithKey:self.shared iv:self.decryptIV];
    self.decryptIV = cbcIv(data);
    return decrypted;
}
@end
