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

        it(@"should create a new client when receiving a connection", ^{
            WHKeyExchangeServer *server = [[WHKeyExchangeServer alloc] initWithIntroData:[NSData data]];

            dispatch_queue_t queue = dispatch_queue_create(NULL, NULL);
            GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                                delegateQueue:queue];
            [socket connectToHost:@"localhost" onPort:[server port] error:nil];

            expect([server.clients first]).notTo.beNil();
        });
    });
});
SpecEnd
