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
- (NSData *)sign:(NSString *)string withKey:(SecKeyRef)key {
    NSData *messageData = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSData *hash = [messageData sha256];
    NSData *signedHash = [hash wh_sign:key];
    NSMutableData *signedMessage = [NSMutableData dataWithData:messageData];
    [signedMessage appendData:signedHash];
    return signedMessage;
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
    NSData *encryptedKey = [sessionKey wh_encryptWithKey:senderKey.privateKey];

    NSMutableData *result = [encryptedKey mutableCopy];
    [result appendData:encryptedMessage];
    return result;
}

- (NSString *)decrypt:(NSData *)data
            senderKey:(WHKeyPair *)senderKey
          receiverKey:(WHKeyPair *)receiverKey
{
    return nil;
}
@end
