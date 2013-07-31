//
//  keyExchangeTests.m
//  whisper
//
//  Created by Thomas Goyne on 7/24/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "Contact.h"
#import "WHBonjourServer.h"
#import "WHBonjourServerBrowser.h"
#import "WHCoreData.h"
#import "WHKeyExchangeClient.h"
#import "WHKeyExchangePeer.h"
#import "WHKeyExchangeServer.h"
#import "WHKeyPair.h"
#import "WHPeerList.h"

#import "Specta.h"
#define EXP_SHORTHAND
#import "Expecta.h"

#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import <OCMock/OCMock.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

SpecBegin(KeyExchangeTests)
describe(@"Bonjour", ^{
    describe(@"WHBonjourServer", ^{
        it(@"should find the local service", ^AsyncBlock{
            WHBonjourServer *server = [[WHBonjourServer alloc] initWithName:@"name" port:12345];
            WHBonjourServerBrowser *browser = [WHBonjourServerBrowser new];
            [browser.netServices subscribeNext:^(NSNetService *service) {
                expect(service.name).to.equal(@"name");
                expect(service.port).to.equal(12345);
                (void)server;
                (void)browser;
                done();
            }];
        });
    });
});

describe(@"Key Exchange", ^{
    beforeEach(^{
        [(id)[[UIApplication sharedApplication] delegate] initTestContext];
    });

    NSDictionary *contactInfo1 = @{@"info": @{@"name": @"contact name",
                                              @"jid": @"foo@localhost"}};
    NSDictionary *contactInfo2 = @{@"info": @{@"name": @"second contact name",
                                              @"jid": @"bar@localhost"}};
    NSData *contactData1 = [NSJSONSerialization dataWithJSONObject:contactInfo1
                                                           options:0 error:nil];
    NSData *contactData2 = [NSJSONSerialization dataWithJSONObject:contactInfo2
                                                           options:0 error:nil];

    describe(@"WHKeyExchangeServer", ^{
        it(@"should automatically pick a port", ^{
            WHKeyExchangeServer *server = [[WHKeyExchangeServer alloc] initWithIntroData:[NSData data]];
            expect(server.port).to.beGreaterThan(0);
        });

        it(@"should send complete signal when disposed", ^{
            WHKeyExchangeServer *server = [[WHKeyExchangeServer alloc] initWithIntroData:[NSData data]];
            RACSignal *clients = server.clients;
            server = nil;
            expect([clients first]).to.beNil(); // blocks forever if no complete signal is sent
        });

        void (^connect)(uint16_t port) = ^(uint16_t port){
            dispatch_queue_t queue = dispatch_queue_create(NULL, NULL);
            GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                                delegateQueue:queue];
            [socket connectToHost:@"localhost" onPort:port error:nil];
        };

        it(@"should create a new client when receiving a connection", ^{
            WHKeyExchangeServer *server = [[WHKeyExchangeServer alloc] initWithIntroData:[NSData data]];
            connect(server.port);
            expect([server.clients first]).notTo.beNil();
        });

        it(@"should pass the given data to the newly created client", ^{
            NSData *data = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
            WHKeyExchangeServer *server = [[WHKeyExchangeServer alloc] initWithIntroData:data];
            connect(server.port);
            expect([[server.clients first] introData]).to.equal(data);
        });
    });

    describe(@"WHKeyExchangeClient", ^{
        id (^mock)(NSData *) = ^(NSData *expectedData) {
            id mockSocket = [OCMockObject mockForClass:[GCDAsyncSocket class]];
            [[mockSocket expect] writeData:expectedData withTimeout:-1 tag:0];
            [[mockSocket expect] writeData:[GCDAsyncSocket ZeroData] withTimeout:-1 tag:0];
            [[mockSocket stub] readDataToData:[GCDAsyncSocket ZeroData] withTimeout:-1 tag:0];
            [[mockSocket stub] setDelegate:OCMOCK_ANY];
            return mockSocket;
        };

        it(@"should write introData on creation", ^{
            id mockSocket = mock(contactData1);
            (void)[[WHKeyExchangeClient alloc] initWithSocket:mockSocket introData:contactData1];
            [mockSocket verify];
        });

        it(@"should create a peer when fed introData", ^AsyncBlock{
            id mockSocket = mock(contactData1);
            WHKeyExchangeClient *client = [[WHKeyExchangeClient alloc]
                                           initWithSocket:mockSocket
                                           introData:contactData1];
            [(id)client socket:nil didReadData:contactData2 withTag:0];
            [client.peer subscribeNext:^(WHKeyExchangePeer *peer) {
                expect(peer.name).to.equal(@"second contact name");
                done();
            }];
        });

        it(@"should create a peer upon connecting", ^AsyncBlock{
            WHKeyExchangeServer *server = [[WHKeyExchangeServer alloc] initWithIntroData:contactData1];
            WHKeyExchangeClient *client = [[WHKeyExchangeClient alloc]
                                           initWithDomain:@"localhost"
                                           port:server.port
                                           introData:contactData2];
            [client.peer
             subscribeNext:^(WHKeyExchangePeer *peer) {
                 expect(peer.name).to.equal(@"contact name");
                 (void)server; // Capture in the block so it stays alive long enough
                 (void)client;
                 done();
             }
             error:^(NSError *error) {
                 expect(error).to.beNil();
                 done();
             }];
        });
    });

    describe(@"WHKeyExchangePeer", ^{
        __block WHKeyExchangeServer *server;
        __block WHKeyExchangeClient *client1, *client2;
        __block WHKeyExchangePeer *peer1, *peer2;

        beforeEach(^{
            server = [[WHKeyExchangeServer alloc] initWithIntroData:contactData1];
            client1 = [[WHKeyExchangeClient alloc] initWithDomain:@"localhost"
                                                             port:server.port
                                                        introData:contactData2];
            client2 = [server.clients first];
            peer1 = [client1.peer first];
            peer2 = [client2.peer first];
        });

        afterEach(^{
            SecItemDelete((__bridge CFDictionaryRef)@{(__bridge id)kSecClass: (__bridge id)kSecClassKey});
        });

        describe(@"wantsToConnect", ^{
            it(@"should initially be false", ^{
                expect(peer1.wantsToConnect).to.beFalsy();
            });

            it(@"should get set to true when a public key is received", ^{
                [client1.publicKey sendNext:[NSData data]];
                expect(peer1.wantsToConnect).to.beTruthy();
            });
        });

        it(@"should create a keypair when receiving a key", ^{
            WHKeyPair *key = [WHKeyPair createKeyPairForJid:@"foo@localhost"];
            [client1.publicKey sendNext:key.publicKeyBits];

            expect([WHKeyPair getKeyFromJid:@"foo@localhost"]).notTo.beNil();
        });

        it(@"should send a new key over the socket when connect is called", ^AsyncBlock{
            [RACAble(peer2, wantsToConnect) subscribeNext:^(id _) {
                expect([WHKeyPair getKeyFromJid:@"foo@localhost"]).notTo.beNil();
                done();
            }];

            [peer1 connect];
        });

        describe(@"completed", ^{
            it(@"should complete on the outgoing connection once the connection is complete", ^AsyncBlock{
                [peer1.connected subscribeCompleted:^{ done(); }];

                [peer1 connect];
                [peer2 connect];
            });

            it(@"should complete on the incoming connection once the connection is complete", ^AsyncBlock{
                [peer2.connected subscribeCompleted:^{ done(); }];

                [peer1 connect];
                [peer2 connect];
            });
        });

        it(@"should create a new Contact after both ends have connected", ^AsyncBlock{
            [[peer1.connected zipWith:peer2.connected]
             subscribeCompleted:^{
                 expect([Contact all]).to.haveCountOf(2);
                 done();
             }];

            [peer1 connect];
            [peer2 connect];
        });
    });
});
SpecEnd
