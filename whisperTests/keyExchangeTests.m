//
//  keyExchangeTests.m
//  whisper
//
//  Created by Thomas Goyne on 7/24/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHBonjourServer.h"
#import "WHBonjourServerBrowser.h"
#import "WHKeyExchangeClient.h"
#import "WHKeyExchangePeer.h"
#import "WHKeyExchangeServer.h"
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
        xit(@"should find the local service", ^AsyncBlock{
            WHBonjourServer *server = [[WHBonjourServer alloc] initWithName:@"name" port:12345];
            WHBonjourServerBrowser *browser = [WHBonjourServerBrowser new];
            [browser.netServices subscribeNext:^(NSNetService *service) {
                expect(service.name).to.equal(@"name");
                (void)server;
                done();
            }];
        });
    });
});

describe(@"Key Exchange", ^{
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
        NSDictionary *contactInfo1 = @{@"info": @{@"name": @"contact name",
                                                  @"jid": @"foo@localhost"}};
        NSDictionary *contactInfo2 = @{@"info": @{@"name": @"second contact name",
                                                  @"jid": @"bar@localhost"}};
        NSData *contactData1 = [NSJSONSerialization dataWithJSONObject:contactInfo1
                                                               options:0 error:nil];
        NSData *contactData2 = [NSJSONSerialization dataWithJSONObject:contactInfo2
                                                               options:0 error:nil];

        id (^mock)(NSData *) = ^(NSData *expectedData){
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

        xit(@"should create a peer upon connecting", ^AsyncBlock{
            WHKeyExchangeServer *server = [[WHKeyExchangeServer alloc] initWithIntroData:contactData1];
            WHKeyExchangeClient *client = [[WHKeyExchangeClient alloc]
                                           initWithDomain:@"localhost"
                                           port:server.port
                                           introData:contactData2];
            [client.peer
             subscribeNext:^(WHKeyExchangePeer *peer) {
                 expect(peer.name).to.equal(@"contact name");
                 done();
             }
             error:^(NSError *error) {
                 expect(error).to.beNil();
                 done();
             }];
        });
    });
});
SpecEnd
