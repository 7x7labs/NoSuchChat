//
//  whisperTests.m
//  whisperTests
//
//  Created by Thomas Goyne on 7/9/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "Contact.h"
#import "Message.h"
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

        it(@"should return newly sent messages", ^AsyncBlock{
            [[contact addSentMessage:@"test message" date:[NSDate date]]
             subscribeCompleted:^{
                 expect(contact.messages).to.haveCountOf(1);
                 expect([[contact.messages anyObject] text]).to.equal(@"test message");
                 done();
             }];
        });

        it(@"should return newly received messages", ^AsyncBlock{
            [[contact addReceivedMessage:@"test message" date:[NSDate date]]
             subscribeCompleted:^{
                 expect(contact.messages).to.haveCountOf(1);
                 expect([[contact.messages anyObject] text]).to.equal(@"test message");
                 done();
             }];
        });

        it(@"should only return messages involving the current contact", ^AsyncBlock{
            Contact *contact2 = [Contact createWithName:@"second contact" jid:@"b@b.com"];
            [[contact2 addSentMessage:@"message" date:[NSDate date]]
             subscribeCompleted:^{
                 expect(contact.messages).to.haveCountOf(0);
                 expect(contact2.messages).to.haveCountOf(1);
                 done();
             }];
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
    beforeEach(^{
        for (NSDictionary *account in [SSKeychain allAccounts])
            [SSKeychain deletePasswordForService:account[kSSKeychainWhereKey]
                                         account:account[kSSKeychainAccountKey]];

    });

    it(@"should return the same account from multiple calls to +get", ^{
        WHAccount *a1 = [WHAccount get];
        WHAccount *a2 = [WHAccount get];
        expect(a1.jid).to.equal(a2.jid);
        expect(a1.password).to.equal(a2.password);
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
            WHKeyPair *kp = [WHKeyPair createKeyPairForJid:contact.jid];
            [WHKeyPair addKey:kp.publicKeyBits fromJid:contact.jid];
        });
        afterEach(^{
            SecItemDelete((__bridge CFDictionaryRef)@{(__bridge id)kSecClass: (__bridge id)kSecClassKey});
        });

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincompatible-pointer-types"
        it(@"should send the message to the stream", ^{
            [[xmppStream expect] sendMessage:OCMOCK_ANY to:@"jid@localhost"];
            [client sendMessage:@"body" to:contact];
            [xmppStream verify];
        });

        it(@"should add an outgoing message to the contact", ^AsyncBlock{
            [[xmppStream expect] sendMessage:OCMOCK_ANY to:@"jid@localhost"];
            [[client sendMessage:@"body" to:contact]
             subscribeCompleted:^{
                 expect(contact.messages).to.haveCountOf(1);
                 expect([[contact.messages anyObject] incoming]).to.beFalsy();
                 done();
             }];
        });
#pragma clang diagnostic pop
    });

    describe(@"message receiving", ^{
        __block Contact *contact;
        beforeEach(^{
            contact = [Contact createWithName:@"name" jid:@"jid@localhost"];
            WHKeyPair *kp = [WHKeyPair createKeyPairForJid:contact.jid];
            [WHKeyPair addKey:kp.publicKeyBits fromJid:contact.jid];
        });
        afterEach(^{
            SecItemDelete((__bridge CFDictionaryRef)@{(__bridge id)kSecClass: (__bridge id)kSecClassKey});
        });

        it(@"should not trigger an error on an unknown contact", ^AsyncBlock{
            [client.incomingMessages
             subscribeNext:^(id _){
                expect(contact.messages).to.haveCountOf(0);
                done();
            }
             error:^(NSError *error) {
                 expect(error).to.beNil();
                 done();
             }];
            [messages sendNext:[[WHChatMessage alloc] initWithSenderJid:@"unknown@localhost"
                                                                   body:@"body"]];
        });

        it(@"should not add messages to the wrong contact", ^AsyncBlock{
            [client.incomingMessages subscribeNext:^(id _){
                expect(contact.messages).to.haveCountOf(0);
                done();
            }];
            [messages sendNext:[[WHChatMessage alloc] initWithSenderJid:@"unknown@localhost"
                                                                   body:@"body"]];
        });

        it(@"should add messages to known contacts to that contact", ^AsyncBlock{
            [client.incomingMessages subscribeNext:^(id _){
                expect(contact.messages).to.haveCountOf(1);
                expect([[contact.messages anyObject] incoming]).to.beTruthy();
                done();
            }];
            [messages sendNext:[[WHChatMessage alloc] initWithSenderJid:@"jid@localhost"
                                                                   body:@"body"]];
        });

    });
});

SpecEnd
