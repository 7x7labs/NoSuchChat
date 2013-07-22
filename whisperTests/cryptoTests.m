//
//  cryptoTests.m
//  whisper
//
//  Created by Thomas Goyne on 7/21/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "NSData+Compression.h"
#import "NSData+Encryption.h"
#import "NSData+SHA.h"
#import "NSData+Signature.h"
#import "WHKeyPair.h"
#import "WHPGP.h"

#import "Specta.h"
#define EXP_SHORTHAND
#import "Expecta.h"

SpecBegin(CryptoTests)

describe(@"NSData+SHA", ^{
    it(@"should correctly hash the empty string", ^{
        const uint8_t expected[] = "\xe3\xb0\xc4\x42\x98\xfc\x1c\x14\x9a\xfb\xf4\xc8\x99\x6f\xb9\x24\x27\xae\x41\xe4\x64\x9b\x93\x4c\xa4\x95\x99\x1b\x78\x52\xb8\x55";
        expect([[NSData data] sha256]).to.equal([NSData dataWithBytes:expected length:sizeof(expected) - 1]);
    });

    it(@"should correctly hash a non-empty string", ^{
        const uint8_t expected[] = "\xd7\xa8\xfb\xb3\x07\xd7\x80\x94\x69\xca\x9a\xbc\xb0\x08\x2e\x4f\x8d\x56\x51\xe4\x6d\x3c\xdb\x76\x2d\x02\xd0\xbf\x37\xc9\xe5\x92";
        NSString *str = @"The quick brown fox jumps over the lazy dog";
        expect([[NSData dataWithBytes:[str UTF8String] length:[str length]] sha256]).to.equal([NSData dataWithBytes:expected length:sizeof(expected) - 1]);
    });
});

describe(@"WHKeyPair", ^{
    afterEach(^{
        SecItemDelete((__bridge CFDictionaryRef)@{(__bridge id)kSecClass: (__bridge id)kSecClassKey});
    });
    describe(@"createKeyPairForJid", ^{
        it(@"should return a valid key pair", ^{
            WHKeyPair *kp = [WHKeyPair createKeyPairForJid:@"foo@localhost"];
            expect(kp.publicKey).notTo.beNil();
            expect(kp.privateKey).notTo.beNil();
            expect(kp.publicKeyBits).notTo.beNil();
        });

        it(@"should replace any existing key pairs for the given jid", ^{
            WHKeyPair *kp = [WHKeyPair createKeyPairForJid:@"foo@localhost"];
            NSData *initialBits = kp.publicKeyBits;
            kp = [WHKeyPair createKeyPairForJid:@"foo@localhost"];
            expect(kp.publicKeyBits).notTo.equal(initialBits);
        });
    });

    describe(@"getOwnKeyPairForJid", ^{
        it(@"should return nil if no key pair has been generated", ^{
            expect([WHKeyPair getOwnKeyPairForJid:@"foo@localhost"]).to.beNil();
        });

        it(@"should return a key pair after a call to createKeyPairForJid:", ^{
            [WHKeyPair createKeyPairForJid:@"foo@localhost"];
            expect([WHKeyPair getOwnKeyPairForJid:@"foo@localhost"]).notTo.beNil();
        });
    });

    describe(@"getKeyFromJid", ^{
        it(@"should return nil if not key for jid has been added", ^{
            expect([WHKeyPair getKeyFromJid:@"foo@localhost"]).to.beNil();
        });

        it(@"should return the added key after addKey:fromJid:", ^{
            NSData *key = [WHKeyPair createKeyPairForJid:@"bar@localhost"].publicKeyBits;
            [WHKeyPair addKey:key fromJid:@"foo@localhost"];
            WHKeyPair *kp = [WHKeyPair getKeyFromJid:@"foo@localhost"];
            expect(kp).notTo.beNil();
            expect(kp.publicKeyBits).to.equal(key);
        });
    });

    describe(@"addKey:fromJid", ^{
        it(@"should replace the existing key from a jid", ^{
            NSData *key1 = [@"key1" dataUsingEncoding:NSUTF8StringEncoding];
            NSData *key2 = [@"key2" dataUsingEncoding:NSUTF8StringEncoding];
            [WHKeyPair addKey:key1 fromJid:@"foo@localhost"];
            WHKeyPair *kp = [WHKeyPair addKey:key2 fromJid:@"foo@localhost"];
            expect(kp.publicKeyBits).to.equal(key2);
        });
    });
});

describe(@"NSData+Signature", ^{
    __block SecKeyRef public, private;
    __block SecKeyRef public2, private2;
    __block NSData *message, *message2;

    beforeAll(^{
        NSDictionary *opt = @{
                              (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
                              (__bridge id)kSecAttrKeySizeInBits: @512,
                              (__bridge id)kSecAttrIsPermanent: @NO
                              };
        SecKeyGeneratePair((__bridge CFDictionaryRef)opt, &public, &private);
        SecKeyGeneratePair((__bridge CFDictionaryRef)opt, &public2, &private2);

        message = [[@"hello" dataUsingEncoding:NSUTF8StringEncoding] sha256];
        message2 = [[@"goodbye" dataUsingEncoding:NSUTF8StringEncoding] sha256];
    });


    describe(@"wh_sign", ^{
        it(@"should return a blob of data", ^{
            expect([message wh_sign:private]).notTo.beNil();
        });

        it(@"should return different blobs of data for different keys", ^{
            expect([message wh_sign:private]).notTo.equal([message wh_sign:private2]);
        });

        it(@"should return different blobs of data for different messages", ^{
            expect([message wh_sign:private]).notTo.equal([message2 wh_sign:private]);
        });
    });

    describe(@"wh_verifySignature:withKey:", ^{
        it(@"should return YES for signature with correct key", ^{
            NSData *sig = [message wh_sign:private];
            expect([message wh_verifySignature:sig withKey:public]).to.beTruthy();
        });

        it(@"should return NO for signature with wrong key", ^{
            NSData *sig = [message wh_sign:private];
            expect([message wh_verifySignature:sig withKey:public2]).to.beFalsy();
        });

        it(@"should return NO for signature for a different blob", ^{
            NSData *sig = [message wh_sign:private];
            expect([message2 wh_verifySignature:sig withKey:public]).to.beFalsy();
        });
    });
});

describe(@"NSData+Compression", ^{
    describe(@"wh_compress", ^{
        it(@"should return empty given empty", ^{
            expect([[NSData data] wh_compress].length).to.equal(0);
        });

        it(@"should do stuff given non-empty input", ^{
            NSData *data = [@"foo" dataUsingEncoding:NSUTF8StringEncoding];
            expect([data wh_compress]).notTo.equal(data);
        });
    });

    describe(@"wh_decompress", ^{
        it(@"should return empty given empty", ^{
            expect([[NSData data] wh_decompress].length).to.equal(0);
        });

        it(@"should return nil given garbage input", ^{
            NSData *data = [@"foo" dataUsingEncoding:NSUTF8StringEncoding];
            expect([data wh_decompress]).to.beNil();
        });

        it(@"should successfully reverse wh_compression", ^{
            NSData *data = [@"foo" dataUsingEncoding:NSUTF8StringEncoding];
            expect([[data wh_compress] wh_decompress]).to.equal(data);
        });
    });
});

describe(@"NSData+Encryption", ^{
    describe(@"wh_createSessionKey", ^{
        it(@"should generate a 32-byte blob", ^{
            expect([[NSData wh_createSessionKey] length]).to.equal(32);
        });
    });

    describe(@"wh_AES256EncryptWithKey", ^{
        it(@"should pad output to 16-byte multiples", ^{
            NSData *key = [NSMutableData dataWithLength:32];
            NSData *encrypted = [[@"hello" dataUsingEncoding:NSUTF8StringEncoding]
                                 wh_AES256EncryptWithKey:key];
            expect(encrypted.length).to.equal(16);
        });

        it(@"should return something different from the input", ^{
            NSData *key = [NSMutableData dataWithLength:32];
            NSData *plainText = [@"1234567890ABCDEF" dataUsingEncoding:NSUTF8StringEncoding];
            NSData *encrypted = [plainText wh_AES256EncryptWithKey:key];
            expect([encrypted rangeOfData:plainText
                                  options:0
                                    range:NSMakeRange(0, [encrypted length])].length).to.equal(0);
        });

        it(@"should return nil given an invalid key", ^{
            NSData *key = [NSMutableData dataWithLength:31];
            NSData *encrypted = [[@"hello" dataUsingEncoding:NSUTF8StringEncoding]
                                 wh_AES256EncryptWithKey:key];
            expect(encrypted).to.beNil();
        });
    });

    describe(@"wh_AES256DecryptWithKey", ^{
        it(@"should reverse the effects of wh_AES256EncryptWithKey", ^{
            NSData *key = [NSMutableData dataWithLength:32];
            NSData *plainText = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
            NSData *encrypted = [plainText wh_AES256EncryptWithKey:key];
            NSData *decrypted = [encrypted wh_AES256DecryptWithKey:key];

            expect(decrypted).to.equal(plainText);
        });
    });
});

describe(@"WHPGP", ^{
    __block WHKeyPair *sender, *recipient;
    __block WHPGP *pgp;

    beforeAll(^{
        sender = [WHKeyPair createKeyPairForJid:@"a@localhost"];
        recipient = [WHKeyPair createKeyPairForJid:@"b@localhost"];
        pgp = [WHPGP new];
    });

    afterAll(^{
        SecItemDelete((__bridge CFDictionaryRef)@{(__bridge id)kSecClass: (__bridge id)kSecClassKey});
    });

    describe(@"encrypt:senderKey:receiverKey:", ^{
        it(@"should return a blob of data", ^{
            NSString *message = @"hello";
            NSData *encrypted = [pgp encrypt:message
                                   senderKey:sender
                                 receiverKey:recipient];
            expect(encrypted).toNot.beNil();
            expect([encrypted length]).to.beGreaterThan(message.length);
        });

        it(@"should return different data each time it is called", ^{
            NSString *message = @"hello";
            NSData *e1 = [pgp encrypt:message senderKey:sender receiverKey:recipient];
            NSData *e2 = [pgp encrypt:message senderKey:sender receiverKey:recipient];
            expect(e1).notTo.equal(e2);
        });
    });

    describe(@"decrypt:senderKey:receiverKey:", ^{
        it(@"should return nil when given invalid data", ^{
            NSData *message = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
            NSString *decrypted = [pgp decrypt:message
                                     senderKey:sender
                                   receiverKey:recipient];
            expect(decrypted).to.beNil();
        });

        it(@"should return nil when given the wrong key", ^{
            NSString *message = @"hello";
            NSData *encrypted = [pgp encrypt:message
                                   senderKey:sender
                                 receiverKey:recipient];
            NSString *decrypted = [pgp decrypt:encrypted
                                     senderKey:recipient
                                   receiverKey:sender];
            expect(decrypted).to.beNil();
        });

        it(@"should be able to decrypt stuff it encrypted", ^{
            NSString *message = @"hello";
            NSData *encrypted = [pgp encrypt:message
                                   senderKey:sender
                                 receiverKey:recipient];
            NSString *decrypted = [pgp decrypt:encrypted
                                     senderKey:sender
                                   receiverKey:recipient];
            expect(decrypted).to.equal(message);
        });
    });
});

SpecEnd
