//
//  WHPGP.m
//  whisper
//
//  Created by Thomas Goyne on 7/18/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHPGP.h"

#import "NSData+Compression.h"
#import "NSData+Encryption.h"
#import "NSData+SHA.h"
#import "NSData+Signature.h"
#import "WHKeyPair.h"

#import <CommonCrypto/CommonCrypto.h>

#define kBlockSize  kCCBlockSizeAES128
#define kKeySize    kCCKeySizeAES256

@implementation WHPGP
- (NSData *)packData:(NSArray *)arr {
    NSUInteger outputLength = [[arr valueForKeyPath:@"@sum.length"] unsignedIntegerValue]
                               + [arr count] * 4;
    NSMutableData *ret = [NSMutableData dataWithCapacity:outputLength];
    uint8_t *dst = [ret mutableBytes];
    for (NSData *sourceData in arr) {
        NSUInteger length = [sourceData length];
        for (size_t i = 0; i < 4; ++i) {
            *dst++ = length & 0xFF;
            length >>= 8;
        }
        memcpy(dst, [sourceData bytes], [sourceData length]);
        dst += [sourceData length];
    }
    return ret;
}

- (NSArray *)unpackData:(NSData *)data {
    NSMutableArray *ret = [NSMutableArray array];
    const uint8_t *src = [data bytes];
    const uint8_t *end = src + [data length];
    while (end - src >= 4) {
        NSUInteger length = 0;
        for (size_t i = 0; i < 4; ++i) {
            length <<= 8;
            length += *src;
        }

        if (end - src < length)
            break;
        [ret addObject:[NSData dataWithBytes:src length:length]];
        src += length;
    }
    return ret;
}

- (NSData *)sign:(NSString *)string withKey:(SecKeyRef)key {
    NSData *messageData = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSData *hash = [messageData sha256];
    NSData *signedHash = [hash wh_sign:key];
    return [self packData:@[messageData, signedHash]];
}

- (NSData *)encrypt:(NSString *)string
          senderKey:(WHKeyPair *)senderKey
        receiverKey:(WHKeyPair *)receiverKey
{
    // High-level description of encryption process (per RFC 4480):
    // 1. Sign the message using the sender's private key
    // 2. Compress the message + signature (size benefits are probably trivial
    //    in our case, but the RFC claims it improves security)
    // 3. Generate session key for symmetric encryption
    // 4. Encrypt compressed message + signature with session key
    // 5. Encrypt session key with recipient's public key
    // 6. Concat encrypted message to encrypted session key
    //
    // We differ from OpenPGP in the following ways:
    // 1. We don't use the OpenPGP packet format as we don't care about interop
    //    and it adds overhead.
    // 2. CommonCrypto's CFB is different from OpenPGP.

    NSData *signedMessage = [self sign:string withKey:senderKey.privateKey];
    NSData *compressedMessage = [signedMessage wh_compress];
    NSData *sessionKey = [NSData wh_createSessionKey];
    NSData *encryptedMessage = [compressedMessage wh_AES256EncryptWithKey:sessionKey];
    NSData *encryptedKey = [sessionKey wh_encryptWithKey:receiverKey.publicKey];
    return [self packData:@[encryptedKey, encryptedMessage]];
}

- (NSString *)decrypt:(NSData *)data
            senderKey:(WHKeyPair *)senderKey
          receiverKey:(WHKeyPair *)receiverKey
{
    // The reverse of the above process, naturally
    NSArray *keyAndMessage = [self unpackData:data];
    NSData *sessionKey = [keyAndMessage[0] wh_decryptWithKey:receiverKey.privateKey];
    NSData *compressedMessage = [keyAndMessage[1] wh_AES256DecryptWithKey:sessionKey];
    NSData *signedMessage = [compressedMessage wh_decompress];
    NSArray *messageAndSignedHash = [self unpackData:signedMessage];
    NSData *hash = [messageAndSignedHash[0] sha256];
    if ([hash wh_verifySignature:messageAndSignedHash[1] withKey:senderKey.publicKey])
        return nil; // maybe report error?
    return messageAndSignedHash[0];
}
@end