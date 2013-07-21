//
//  whisperTests.m
//  whisperTests
//
//  Created by Thomas Goyne on 7/9/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "Contact.h"
#import "Message.h"
#import "NSData+Compression.h"
#import "NSData+Encryption.h"
#import "NSData+SHA.h"
#import "NSData+Signature.h"
#import "WHAccount.h"
#import "WHChatClient.h"
#import "WHCoreData.h"
#import "WHKeyPair.h"
#import "WHXMPPWrapper.h"

#import "Specta.h"
#define EXP_SHORTHAND
#import "Expecta.h"

#import <OCMock/OCMock.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <SSKeychain/SSKeychain.h>

SpecBegin(WhisperTests)

describe(@"Contact", ^{
    beforeEach(^{
        [(id)[[UIApplication sharedApplication] delegate] initTestContext];
    });

    it(@"should initially return an empty array from all", ^{
        expect([Contact all]).to.haveCountOf(0);
    });

    it(@"should be able to create new contacts with the specified name", ^{
        Contact *contact = [Contact createWithName:@"abc" jid:@"a@b.com"];
        expect(contact).notTo.beNil();
        expect(contact.name).to.equal(@"abc");
    });

    it(@"should return newly created contacts from all", ^{
        [Contact createWithName:@"def" jid:@"a@b.com"];
        NSArray *all = [Contact all];
        expect(all).to.haveCountOf(1);
        expect([all[0] name]).to.equal(@"def");
    });

    describe(@"messages", ^{
        __block Contact *contact;
        beforeEach(^{
            contact = [Contact createWithName:@"test contact" jid:@"a@b.com"];
        });

        it(@"should initially be empty", ^{
            expect(contact.messages).to.haveCountOf(0);
        });

        it(@"should return newly sent messages", ^{
            [contact addSentMessage:@"test message" date:[NSDate date]];
            expect(contact.messages).to.haveCountOf(1);
            expect([[contact.messages anyObject] text]).to.equal(@"test message");
        });

        it(@"should return newly received messages", ^{
            [contact addReceivedMessage:@"test message" date:[NSDate date]];
            expect(contact.messages).to.haveCountOf(1);
            expect([[contact.messages anyObject] text]).to.equal(@"test message");
        });

        it(@"should only return messages involving the current contact", ^{
            Contact *contact2 = [Contact createWithName:@"second contact" jid:@"b@b.com"];
            [contact2 addSentMessage:@"message" date:[NSDate date]];
            expect(contact.messages).to.haveCountOf(0);
            expect(contact2.messages).to.haveCountOf(1);
        });
    });

    describe(@"createWithName:jid:", ^{
        it(@"should return the existing contact if given a duplicate jid", ^{
            Contact *c1 = [Contact createWithName:@"abc" jid:@"a@b.com"];
            Contact *c2 = [Contact createWithName:@"def" jid:@"a@b.com"];
            expect(c1).to.equal(c2);
        });
    });
});

describe(@"WHAccount", ^{
    it(@"should return the same account from multiple calls to +get", ^{
        WHAccount *a1 = [WHAccount get];
        WHAccount *a2 = [WHAccount get];
        expect(a1.jid).to.equal(a2.jid);
        expect(a1.password).to.equal(a2.password);
    });

    afterEach(^{
        for (NSDictionary *account in [SSKeychain allAccounts])
            [SSKeychain deletePasswordForService:nil account:account[kSSKeychainAccountKey]];

    });
});

describe(@"WHChatClient", ^{
    __block WHChatClient *client;
    __block id xmppStream;
    __block RACSubject *messages;
    beforeEach(^{
        [(id)[[UIApplication sharedApplication] delegate] initTestContext];
        messages = [RACSubject subject];
        xmppStream = [OCMockObject mockForProtocol:@protocol(WHXMPPStream)];
        [[[xmppStream expect] andReturn:messages] messages];
        [[[xmppStream expect] andReturn:[RACSignal new]] connectToServer:@"localhost"
                                                                    port:5222
                                                                username:[OCMArg any]
                                                                password:[OCMArg any]];
        client = [WHChatClient clientForServer:@"localhost" port:5222 stream:xmppStream];
    });

    it(@"should call the connectToServer:port:username:password:", ^{
        [xmppStream verify];
    });

    describe(@"contacts", ^{
        it(@"should initially be empty", ^{
            expect(client.contacts).to.haveCountOf(0);
        });

        it(@"should add newly created contacts", ^{
            [Contact createWithName:@"name" jid:@"jid@localhost"];
            expect(client.contacts).to.haveCountOf(1);
        });
    });

    describe(@"sendMessage", ^{
        __block Contact *contact;
        beforeEach(^{
            contact = [Contact createWithName:@"name" jid:@"jid@localhost"];
        });

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincompatible-pointer-types"
        it(@"should send the message to the stream", ^{
            [[xmppStream expect] sendMessage:@"body" to:@"jid@localhost"];
            [client sendMessage:@"body" to:contact];
            [xmppStream verify];
        });

        it(@"should add an outgoing message to the contact", ^{
            [[xmppStream expect] sendMessage:@"body" to:@"jid@localhost"];
            [client sendMessage:@"body" to:contact];
            expect(contact.messages).to.haveCountOf(1);
            expect([[contact.messages anyObject] incoming]).to.beFalsy();
        });
#pragma clang diagnostic pop
    });

    describe(@"message receiving", ^{
        __block Contact *contact;
        beforeEach(^{
            contact = [Contact createWithName:@"name" jid:@"jid@localhost"];
        });

        it(@"should not trigger an error on an unknown contact", ^{
            [messages sendNext:[[WHChatMessage alloc] initWithSenderJid:@"unknown@localhost"
                                                                   body:@"body"]];
        });

        it(@"should not add messages to the wrong contact", ^{
            [messages sendNext:[[WHChatMessage alloc] initWithSenderJid:@"unknown@localhost"
                                                                   body:@"body"]];
            expect(contact.messages).to.haveCountOf(0);
        });

        it(@"should add messages to known contacts to that contact", ^{
            [messages sendNext:[[WHChatMessage alloc] initWithSenderJid:@"jid@localhost"
                                                                   body:@"body"]];
            expect(contact.messages).to.haveCountOf(1);
            expect([[contact.messages anyObject] incoming]).to.beTruthy();
        });

    });
});

describe(@"NSData+SHA", ^{
    it(@"should correctly hash the empty string", ^{
        const uint8_t expected[] = "\xe3\xb0\xc4\x42\x98\xfc\x1c\x14\x9a\xfb\xf4\xc8\x99\x6f\xb9\x24\x27\xae\x41\xe4\x64\x9b\x93\x4c\xa4\x95\x99\x1b\x78\x52\xb8\x55";
        expect([[NSData data] sha256]).to.equal([NSData dataWithBytes:expected length:sizeof(expected)]);
    });

    it(@"should correctly hash a non-empty string", ^{
        const uint8_t expected[] = "\xd7\xa8\xfb\xb3\x07\xd7\x80\x94\x69\xca\x9a\xbc\xb0\x08\x2e\x4f\x8d\x56\x51\xe4\x6d\x3c\xdb\x76\x2d\x02\xd0\xbf\x37\xc9\xe5\x92";
        NSString *str = @"The quick brown fox jumps over the lazy dog";
        expect([[NSData dataWithBytes:[str UTF8String] length:[str length]] sha256]).to.equal([NSData dataWithBytes:expected length:sizeof(expected)]);
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
            NSData *key = [@"foo" dataUsingEncoding:NSUTF8StringEncoding];
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
            NSData *hash = [message sha256];
            expect([hash wh_verifySignature:sig withKey:public]).to.beTruthy();
        });

        it(@"should return NO for signature with wrong key", ^{
            NSData *sig = [message wh_sign:private];
            NSData *hash = [message sha256];
            expect([hash wh_verifySignature:sig withKey:public2]).to.beFalsy();
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

SpecEnd
