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
#import "WHCrypto.h"
#import "WHError.h"
#import "WHKeyPair.h"
#import "WHXMPPRoster.h"
#import "WHXMPPWrapper.h"

#import "Specta.h"
#define EXP_SHORTHAND
#import "Expecta.h"
#import "NSData+XMPP.h"
#import "XMPP.h"

#import <OCMock/OCMock.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <libkern/OSAtomic.h>

OSStatus SecItemDeleteAll(void); // private API, do not use outside of tests

@interface WHXMPPWrapper (Test)
- (void)setStream:(XMPPStream *)stream;
@end

// CoreData stuff on background threads doesn't work if the main thread is
// blocked, so do a busy wait for the signal to complete
static void waitForSignalComplete(RACSignal *signal) {
    __block uint32_t complete = 0;
    [signal subscribeCompleted:^{
        OSAtomicOr32Barrier(1, &complete);
    }];
    while (!complete)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

static Contact *createContact(NSString *name, NSString *jid) {
    waitForSignalComplete([Contact createWithName:name jid:jid]);
    return [Contact contactForJid:jid managedObjectContext:[WHCoreData managedObjectContext]];
}

SpecBegin(WhisperTests)

beforeEach(^{
    [WHCoreData initTestContext];
    SecItemDeleteAll();
});

describe(@"Contact", ^{
    it(@"should initially return an empty array from all", ^{
        expect([Contact all]).to.haveCountOf(0);
    });

    it(@"should be able to create new contacts with the specified name", ^AsyncBlock{
        [[Contact createWithName:@"abc" jid:@"a@b.com"] subscribeNext:^(Contact *contact) {
            expect(contact).notTo.beNil();
            expect(contact.name).to.equal(@"abc");
            done();
        }];
    });

    it(@"should return newly created contacts from all", ^AsyncBlock{
        [[[Contact createWithName:@"def" jid:@"a@b.com"]
          deliverOn:[RACScheduler mainThreadScheduler]]
         subscribeCompleted:^{
             NSArray *all = [Contact all];
             expect(all).to.haveCountOf(1);
             expect([all[0] name]).to.equal(@"def");
             done();
         }];
    });

    describe(@"messages", ^{
        __block Contact *contact;
        beforeEach(^{
            contact = createContact(@"test contact", @"a@b.com");
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
            Contact *contact2 = createContact(@"second contact", @"b@b.com");
            [[contact2 addSentMessage:@"message" date:[NSDate date]]
             subscribeCompleted:^{
                 expect(contact.messages).to.haveCountOf(0);
                 expect(contact2.messages).to.haveCountOf(1);
                 done();
             }];
        });

        it(@"should have a message after deleting messages older than the message", ^AsyncBlock{
            [[[contact addSentMessage:@"test message" date:[NSDate date]]
             sequenceNext:^{
                 return [Message deleteOlderThan:[[contact.messages anyObject] sent]];
             }]
             subscribeCompleted:^{
                 expect(contact.messages).to.haveCountOf(1);
                 done();
             }];
        });

        it(@"should be empty after deleting messages older than now", ^AsyncBlock{
            [[[contact addSentMessage:@"test message" date:[NSDate date]]
             sequenceNext:^{
                 return [Message deleteOlderThan:[NSDate date]];
             }]
             subscribeCompleted:^{
                 expect(contact.messages).to.haveCountOf(0);
                 done();
             }];
        });
    });

    describe(@"createWithName:jid:", ^{
        it(@"should return the existing contact if given a duplicate jid", ^{
            Contact *c1 = createContact(@"abc", @"a@b.com");
            Contact *c2 = createContact(@"def", @"a@b.com");
            expect(c1).to.equal(c2);
        });
    });
});

describe(@"Deleting contacts", ^{
    __block Contact *contact;
    __block RACSignal *(^deleteContact)();
    NSString *contactJid = @"a@b.com";
    beforeEach(^{
        contact = createContact(@"test contact", contactJid);
        waitForSignalComplete([contact addSentMessage:@"hello" date:[NSDate date]]);
        deleteContact = ^{
            return [[contact delete] deliverOn:[RACScheduler mainThreadScheduler]];
        };
    });

    it(@"should remove the contact from [Contact all]", ^AsyncBlock{
        [deleteContact() subscribeCompleted:^{
            expect([Contact all]).to.haveCountOf(0);
            done();
        }];
    });

    it(@"should delete keys generated for the contact", ^AsyncBlock{
        [WHKeyPair createKeyPairForJid:contact.jid];
        expect([WHKeyPair getOwnKeyPairForJid:contactJid]).notTo.beNil();
        [deleteContact() subscribeCompleted:^{
             expect([WHKeyPair getOwnKeyPairForJid:contactJid]).to.beNil();
             done();
         }];
    });

    it(@"should not delete keys generated for other contacts", ^AsyncBlock{
        [WHKeyPair createKeyPairForJid:@"otherjid@localhost"];
        [deleteContact() subscribeCompleted:^{
            expect([WHKeyPair getOwnKeyPairForJid:@"otherjid@localhost"]).notTo.beNil();
            done();
        }];
    });

    it(@"should delete keys received from the contact", ^AsyncBlock{
        WHKeyPair *kp = [WHKeyPair createOwnGlobalKeyPair];
        [WHKeyPair addKey:kp.publicKeyBits fromJid:contactJid];
        [WHKeyPair addGlobalKey:kp.publicKeyBits fromJid:contactJid];
        [WHKeyPair addSymmetricKey:kp.symmetricKey fromJid:contactJid];
        [deleteContact() subscribeCompleted:^{
            expect([WHKeyPair getKeyFromJid:contactJid]).to.beNil();
            expect([WHKeyPair getGlobalKeyFromJid:contactJid]).to.beNil();
            done();
        }];
    });

    it(@"should delete messages for the contact", ^AsyncBlock{
        [deleteContact() subscribeCompleted:^{
            NSError *error;
            NSArray *array = [[WHCoreData managedObjectContext]
                              executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"Message"]
                              error:&error];
            expect(error).to.beNil();
            expect(array).to.haveCountOf(0);
            done();
        }];
    });
});

describe(@"WHAccount", ^{
    it(@"should set the jid, password and global key", ^{
        WHAccount *a = [WHAccount get];
        expect([a.jid length]).to.beGreaterThan(0);
        expect([a.password length]).to.beGreaterThan(0);
        expect(a.globalKey.publicKey).notTo.beNil();
        expect(a.globalKey.privateKey).notTo.beNil();
        expect(a.globalKey.publicKeyBits).notTo.beNil();
    });

    it(@"should return the same account from multiple calls to +get", ^{
        WHAccount *a1 = [WHAccount get];
        WHAccount *a2 = [WHAccount get];
        expect(a1.jid).to.equal(a2.jid);
        expect(a1.password).to.equal(a2.password);
        expect(a1.globalKey.publicKeyBits).to.equal(a2.globalKey.publicKeyBits);
    });
});

describe(@"WHChatMessage", ^{
    it(@"should set the sent date to now if it is nil", ^{
        WHChatMessage *message = [[WHChatMessage alloc] initWithSenderJid:@"unknown@localhost"
                                                                     body:@"body"
                                                                     sent:nil];
        expect(message.sent).notTo.beNil();
    });

    it(@"should use the passed sent date if it is not nil", ^{
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:20];
        WHChatMessage *message = [[WHChatMessage alloc] initWithSenderJid:@"unknown@localhost"
                                                                     body:@"body"
                                                                     sent:date];
        expect(message.sent).to.equal(date);
    });
});

describe(@"WHChatClient", ^{
    __block WHChatClient *client;
    __block id xmppStream;
    __block RACSubject *messages;
    __block Contact *contact;
    beforeEach(^{
        messages = [RACSubject subject];
        xmppStream = [OCMockObject niceMockForClass:[WHXMPPWrapper class]];
        [[[xmppStream expect] andReturn:messages] messages];
        [[[xmppStream expect] andReturn:[RACSignal new]] connectToServer:@"localhost"
                                                                    port:5222
                                                                username:OCMOCK_ANY
                                                                password:OCMOCK_ANY];
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
            createContact(@"name", @"jid@localhost");
            expect(client.contacts).to.haveCountOf(1);
        });
    });

    describe(@"sendMessage", ^{
        beforeEach(^{
            contact = createContact(@"name", @"jid@localhost");
            [WHKeyPair addKey:[WHKeyPair createKeyPairForJid:contact.jid].publicKeyBits
                      fromJid:contact.jid];
        });

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincompatible-pointer-types"
        it(@"should send the message to the stream", ^{
            [[[xmppStream expect] andReturn:[RACSignal empty]] sendMessage:OCMOCK_ANY to:@"jid@localhost"];
            [client sendMessage:@"body" to:contact];
            [xmppStream verify];
        });

        it(@"should add an outgoing message to the contact", ^AsyncBlock{
            [[[xmppStream expect] andReturn:[RACSignal empty]] sendMessage:OCMOCK_ANY to:@"jid@localhost"];
            [[client sendMessage:@"body" to:contact]
             subscribeCompleted:^{
                 expect(contact.messages).to.haveCountOf(1);
                 expect([[contact.messages anyObject] incoming]).to.beFalsy();
                 done();
             }];
        });

        it(@"should report XMPP errors", ^AsyncBlock {
            [[[xmppStream expect]
              andReturn:[RACSignal error:[WHError errorWithDescription:@"error"]]]
             sendMessage:OCMOCK_ANY to:@"jid@localhost"];

            [[client sendMessage:@"body" to:contact]
             subscribeError:^(NSError *error) {
                 done();
             } completed:^{
                 expect(NO).to.beTruthy();
                 done();
             }];
        });
#pragma clang diagnostic pop
    });

    describe(@"message receiving", ^{
        beforeEach(^{
            contact = createContact(@"name", @"jid@localhost");
            [WHKeyPair addKey:[WHKeyPair createKeyPairForJid:contact.jid].publicKeyBits
                      fromJid:contact.jid];
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
                                                                   body:@"body"
                                                                   sent:nil]];
        });

        it(@"should not add messages to the wrong contact", ^AsyncBlock{
            [client.incomingMessages subscribeNext:^(id _){
                expect(contact.messages).to.haveCountOf(0);
                done();
            }];
            [messages sendNext:[[WHChatMessage alloc] initWithSenderJid:@"unknown@localhost"
                                                                   body:@"body"
                                                                   sent:nil]];
        });

        it(@"should add messages to known contacts to that contact", ^AsyncBlock{
            [client.incomingMessages subscribeNext:^(id _){
                expect(contact.messages).to.haveCountOf(1);
                expect([[contact.messages anyObject] incoming]).to.beTruthy();
                done();
            }];
            [messages sendNext:[[WHChatMessage alloc] initWithSenderJid:@"jid@localhost"
                                                                   body:@"body"
                                                                   sent:nil]];
        });

    });
});

describe(@"WHXMPPRoster", ^{
    __block id xmppStream;
    __block WHXMPPRoster *roster;
    __block Contact *contact;
    beforeEach(^{
        xmppStream = [OCMockObject mockForClass:[XMPPStream class]];

        [[[xmppStream expect] ignoringNonObjectArgs] addDelegate:OCMOCK_ANY delegateQueue:OCMOCK_ANY];
        roster = [[WHXMPPRoster alloc] initWithXmppStream:xmppStream];
        roster.contactJids = [NSMutableSet set];

        contact = createContact(@"name", @"jid@localhost");
    });
    afterEach(^{
        [[xmppStream stub] removeDelegate:OCMOCK_ANY];
    });

    it(@"should add and remove itself from the stream's delegates", ^{
        [xmppStream verify]; // expect in beforeEach

        [[xmppStream expect] removeDelegate:OCMOCK_ANY];
        roster = nil;
        [xmppStream verify];
    });

    describe(@"addContact:", ^{
        it(@"should add the contact's JID to contactJids", ^{
            [[xmppStream stub] sendElement:OCMOCK_ANY];

            [roster addContact:contact];
            expect(roster.contactJids).to.haveCountOf(1);
        });
    });

    describe(@"xmppStream:didReceiveMessage:", ^{
        __block WHKeyPair *kp;
        beforeEach(^{
            kp = [WHKeyPair createOwnGlobalKeyPair];
            [WHKeyPair addGlobalKey:kp.publicKeyBits fromJid:contact.jid];
            [WHKeyPair addSymmetricKey:kp.symmetricKey fromJid:contact.jid];
        });

        it(@"should set the nickname of known users", ^AsyncBlock{
            NSString *xml = [NSString stringWithFormat:
                             @"<message from='jid@localhost/location'>"
                             @"  <event xmlns='http://jabber.org/protocol/pubsub#event'>"
                             @"    <items node='841f3c8955c4c41a0cf99620d78a33b996659ded'>"
                             @"      <item>"
                             @"        <nick xmlns='http://jabber.org/protocol/nick'>%@</nick>"
                             @"      </item>"
                             @"    </items>"
                             @"  </event>"
                             @"</message>", [[WHCrypto encrypt:@"New Nick" key:kp]
                                             xmpp_base64Encoded]];

            [RACAble(contact, name) subscribeNext:^(id x) {
                expect(x).to.equal(@"New Nick");
                done();
            }];

            [(id)roster xmppStream:nil
                 didReceiveMessage:[XMPPMessage messageFromElement:[[NSXMLElement alloc]
                                                                    initWithXMLString:xml
                                                                    error:nil]]];
            [[xmppStream stub] removeDelegate:OCMOCK_ANY];
        });
    });
});

describe(@"WHXMPPWrapper", ^{
    __block WHXMPPWrapper *xmpp;
    beforeEach(^{
        xmpp = [WHXMPPWrapper new];
    });

    describe(@"setDisplayName", ^{
        it(@"should send an element to the stream", ^{
            id mockStream = [OCMockObject mockForClass:[XMPPStream class]];
            [xmpp setStream:mockStream];
            [[mockStream expect] sendElement:OCMOCK_ANY];

            xmpp.displayName = @"name";

            [mockStream verify];
            [[mockStream stub] sendElement:OCMOCK_ANY];
        });
    });
});

SpecEnd
