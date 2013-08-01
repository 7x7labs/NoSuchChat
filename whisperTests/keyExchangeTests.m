//
//  keyExchangeTests.m
//  whisper
//
//  Created by Thomas Goyne on 7/24/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "Contact.h"
#import "WHCoreData.h"
#import "WHKeyExchangePeer.h"
#import "WHKeyPair.h"
#import "WHMultipeerAdvertiser.h"
#import "WHMultipeerBrowser.h"
#import "WHMultipeerSession.h"
#import "WHPeerList.h"

#import "Specta.h"
#define EXP_SHORTHAND
#import "Expecta.h"

#import <CocoaAsyncSocket/GCDAsyncSocket.h>
#import <OCMock/OCMock.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
@import MultipeerConnectivity;

@interface WHPeerList (Test)
- (WHMultipeerBrowser *)browser;
@end

SpecBegin(KeyExchangeTests)
describe(@"WHMultipeerAdvertiser", ^{
    __block WHMultipeerAdvertiser *advertiser;
    __block id<MCNearbyServiceAdvertiserDelegate> delegate;
    beforeEach(^{
        advertiser = [WHMultipeerAdvertiser new];
        delegate = (id)advertiser;
    });

    it(@"should initially have no peerID", ^{
        expect(advertiser.peerID).to.beNil();
    });

    it(@"should set the peerID when the display name is set", ^{
        advertiser.displayName = @"display name";
        expect(advertiser.peerID).notTo.beNil();
    });

    it(@"should create a new peerID when the display name changes", ^{
        advertiser.displayName = @"display name";
        MCPeerID *oldPeerID = advertiser.peerID;
        advertiser.displayName = @"second display name";
        expect(advertiser.peerID).notTo.equal(oldPeerID);
    });

    it(@"should forward errors to the signal", ^AsyncBlock{
        NSError *error = [NSError errorWithDomain:@"domain" code:0 userInfo:@{}];
        [advertiser.invitations subscribeError:^(NSError *sentError) {
            expect(error).to.equal(sentError);
            done();
        }];
        [delegate advertiser:nil didNotStartAdvertisingPeer:error];
    });

    it(@"should create key exchange peers when invited",  ^AsyncBlock{
        MCPeerID *peerID = [[MCPeerID alloc] initWithDisplayName:@"display name"];
        [advertiser.invitations subscribeNext:^(WHKeyExchangePeer *peer) {
            expect(peer).notTo.beNil();
            done();
        }];

        [delegate advertiser:nil didReceiveInvitationFromPeer:peerID withContext:nil invitationHandler:nil];
    });
});

describe(@"WHMultipeerBrowser", ^{
    __block WHMultipeerAdvertiser *advertiser;
    __block WHMultipeerBrowser *browser;
    __block id<MCNearbyServiceBrowserDelegate> delegate;
    beforeEach(^{
        advertiser = [WHMultipeerAdvertiser new];
        advertiser.displayName = @"display name";

        browser = [[WHMultipeerBrowser alloc] initWithPeer:advertiser.peerID];
        delegate = (id)browser;
    });

    it(@"should forward found peers to the signal", ^AsyncBlock{
        [[browser.peers take:1] subscribeNext:^(MCPeerID *peer) {
            expect(peer).to.equal(advertiser.peerID);
            done();
        }];
        [delegate browser:nil foundPeer:advertiser.peerID withDiscoveryInfo:@{}];
    });

    it(@"should forward removed peers to the signal", ^AsyncBlock{
        [[browser.removedPeers take:1] subscribeNext:^(MCPeerID *peer) {
            expect(peer).to.equal(advertiser.peerID);
            done();
        }];
        [delegate browser:nil lostPeer:advertiser.peerID];
    });

    it(@"should forward errors to the signal", ^AsyncBlock{
        NSError *error = [NSError errorWithDomain:@"domain" code:0 userInfo:@{}];
        [browser.peers subscribeError:^(NSError *sentError) {
            expect(error).to.equal(sentError);
            done();
        }];
        [delegate browser:nil didNotStartBrowsingForPeers:error];
    });
});

describe(@"WHPeerList", ^{
    __block WHPeerList *peerList;
    __block MCPeerID *ownPeerID;
    __block MCPeerID *otherPeerID;
    __block id<MCNearbyServiceBrowserDelegate> delegate;
    beforeEach(^{
        ownPeerID = [[MCPeerID alloc] initWithDisplayName:@"own peer ID"];
        otherPeerID = [[MCPeerID alloc] initWithDisplayName:@"other peer ID"];
        peerList = [[WHPeerList alloc] initWithOwnPeerID:ownPeerID];
        delegate = (id)[peerList browser];
    });

    it(@"should initially be empty", ^{
        expect(peerList.peers).to.haveCountOf(0);
    });

    it(@"should not add own peer id", ^{
        [delegate browser:nil foundPeer:ownPeerID withDiscoveryInfo:@{}];
        expect(peerList.peers).to.haveCountOf(0);
    });

    it(@"should add a different peer id", ^{
        [delegate browser:nil foundPeer:otherPeerID withDiscoveryInfo:@{}];
        expect(peerList.peers).to.haveCountOf(1);
    });

    it(@"should not add duplicates", ^{
        [delegate browser:nil foundPeer:otherPeerID withDiscoveryInfo:@{}];
        [delegate browser:nil foundPeer:otherPeerID withDiscoveryInfo:@{}];
        expect(peerList.peers).to.haveCountOf(1);
    });

    it(@"should removed lost peer ids", ^{
        [delegate browser:nil foundPeer:otherPeerID withDiscoveryInfo:@{}];
        [delegate browser:nil lostPeer:otherPeerID];
        expect(peerList.peers).to.haveCountOf(0);
    });

    it(@"should not error on losing an unknown peer", ^{
        [delegate browser:nil lostPeer:otherPeerID];
        expect(peerList.peers).to.haveCountOf(0);
    });

    it(@"should be KVO compliant", ^AsyncBlock{
        [RACAble(peerList, peers) subscribeNext:^(id _) {
            done();
        }];
        [delegate browser:nil foundPeer:otherPeerID withDiscoveryInfo:@{}];
    });
});

describe(@"WHKeyExchangePeer", ^{
    NSString *contactJid = @"contact@locahost";
    NSString *ownJid = @"ownjid@locahost";
    __block MCPeerID *peerID;
    beforeEach(^{
        peerID = [[MCPeerID alloc] initWithDisplayName:@"display name"];
        [(id)[[UIApplication sharedApplication] delegate] initTestContext];
    });
    afterEach(^{
        SecItemDelete((__bridge CFDictionaryRef)@{(__bridge id)kSecClass: (__bridge id)kSecClassKey});
    });

    describe(@"outgoing connection", ^{
        it(@"should set its name to the peer's display name", ^{
            WHKeyExchangePeer *peer = [[WHKeyExchangePeer alloc] initWithPeerID:peerID browser:nil];
            expect(peer.name).to.equal(@"display name");
        });

        it(@"should ask the browser to connect to the peer", ^{
            id browser = [OCMockObject mockForClass:[WHMultipeerBrowser class]];
            [[[browser expect] andReturn:nil] connectToPeer:peerID];

            WHKeyExchangePeer *peer = [[WHKeyExchangePeer alloc] initWithPeerID:peerID browser:browser];
            [peer connectWithJid:@"ownjid@localhost"];

            [browser verify];
        });

        it(@"should send the user's jid when told to connect", ^AsyncBlock{
            id session = [OCMockObject mockForClass:[WHMultipeerSession class]];
            [[[session expect] andReturn:[RACSignal return:nil]] connected];
            [[[session expect] andReturn:[RACSignal empty]] incomingData];
            [[session expect] sendData:[OCMArg checkWithBlock:^BOOL(NSData *data) {
                expect(data).to.beKindOf([NSData class]);
                expect(data).to.equal([ownJid dataUsingEncoding:NSUTF8StringEncoding]);
                return YES;
            }]];

            id browser = [OCMockObject mockForClass:[WHMultipeerBrowser class]];
            [[[browser expect] andReturn:session] connectToPeer:peerID];

            WHKeyExchangePeer *peer = [[WHKeyExchangePeer alloc] initWithPeerID:peerID browser:browser];
            [[peer connectWithJid:ownJid] subscribeCompleted:^{
                [session verify];
                done();
            }];

        });

        it(@"should send a public key after receiving the contact's JID", ^AsyncBlock{
            id session = [OCMockObject mockForClass:[WHMultipeerSession class]];
            [[[session expect] andReturn:[RACSignal return:nil]] connected];
            [[session expect] sendData:[OCMArg isNotNil]];
            [[[session expect] andReturn:[RACSignal return:[contactJid dataUsingEncoding:NSUTF8StringEncoding]]] incomingData];
            [[session expect] sendData:[OCMArg isNotNil]];
            [[[session expect] andReturn:[RACSignal empty]] incomingData];

            id browser = [OCMockObject mockForClass:[WHMultipeerBrowser class]];
            [[[browser expect] andReturn:session] connectToPeer:peerID];

            WHKeyExchangePeer *peer = [[WHKeyExchangePeer alloc] initWithPeerID:peerID browser:browser];
            [[peer connectWithJid:ownJid] subscribeCompleted:^{
                [session verify];
                done();
            }];
        });

        it(@"should create a new contact once the key exchange is complete", ^AsyncBlock{
            NSData *jid = [contactJid dataUsingEncoding:NSUTF8StringEncoding];
            NSData *keyBits = [WHKeyPair createKeyPairForJid:ownJid].publicKeyBits;
            SecItemDelete((__bridge CFDictionaryRef)@{(__bridge id)kSecClass: (__bridge id)kSecClassKey});

            id session = [OCMockObject mockForClass:[WHMultipeerSession class]];
            [[[session expect] andReturn:[RACSignal return:nil]] connected];
            [[session expect] sendData:[OCMArg isNotNil]];
            [[[session expect] andReturn:[RACSignal return:jid]] incomingData];
            [[session expect] sendData:[OCMArg isNotNil]];
            [[[session expect] andReturn:[RACSignal return:keyBits]] incomingData];

            id browser = [OCMockObject mockForClass:[WHMultipeerBrowser class]];
            [[[browser expect] andReturn:session] connectToPeer:peerID];

            WHKeyExchangePeer *peer = [[WHKeyExchangePeer alloc] initWithPeerID:peerID browser:browser];
            [[peer connectWithJid:@"ownjid@localhost"] subscribeNext:^(Contact *contact) {
                expect(contact.name).to.equal(peerID.displayName);
                expect(contact.ownKey).notTo.beNil();
                expect(contact.ownKey.publicKey).notTo.beNil();
                expect(contact.ownKey.privateKey).notTo.beNil();
                expect(contact.contactKey).notTo.beNil();
                expect(contact.contactKey.publicKey).notTo.beNil();
                expect(contact.contactKey.privateKey).to.beNil();
                done();
            }];
        });
    });

    describe(@"incoming connection", ^{
        it(@"should pass a session to the invitation handler", ^AsyncBlock{
            invitationHandler handler = ^(BOOL accept, MCSession *session){
                expect(accept).to.beTruthy();
                expect(session).to.beKindOf([MCSession class]);
                done();
            };

            WHKeyExchangePeer *peer = [[WHKeyExchangePeer alloc] initWithPeerID:peerID invitation:handler];
            [peer connectWithJid:@"ownjid@localhost"];
        });

        it(@"should be able to reject connections", ^AsyncBlock{
            invitationHandler handler = ^(BOOL accept, MCSession *session){
                expect(accept).to.beFalsy();
                expect(session).to.beNil();
                done();
            };

            WHKeyExchangePeer *peer = [[WHKeyExchangePeer alloc] initWithPeerID:peerID invitation:handler];
            [peer reject];
        });
    });
});
SpecEnd
