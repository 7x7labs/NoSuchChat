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

#import <OCMock/OCMock.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
@import MultipeerConnectivity;

@interface WHPeerList (Test)
- (WHMultipeerBrowser *)browser;
@end

static id isKindOfClass(Class class) {
    return [OCMArg checkWithBlock:^(id obj) {
        return [obj isKindOfClass:class];
    }];
}

OSStatus SecItemDeleteAll(void); // private API, do not use outside of tests

SpecBegin(KeyExchangeTests)
beforeEach(^{
    [WHCoreData initTestContext];
    SecItemDeleteAll();
});

describe(@"WHMultipeerAdvertiser", ^{
    __block WHMultipeerAdvertiser *advertiser;
    __block id<MCNearbyServiceAdvertiserDelegate> delegate;
    beforeEach(^{
        advertiser = [[WHMultipeerAdvertiser alloc] initWithJid:@"jid@localhost"];
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
        advertiser = [[WHMultipeerAdvertiser alloc] initWithJid:@"self@localhost"];
        advertiser.displayName = @"display name";

        browser = [[WHMultipeerBrowser alloc] initWithPeer:advertiser.peerID];
        delegate = (id)browser;
    });

    it(@"should forward found peers to the signal", ^AsyncBlock{
        [[browser.peers take:1] subscribeNext:^(RACTuple *peer) {
            RACTupleUnpack(MCPeerID *peerID, NSString *peerJid) = peer;
            expect(peerID).to.equal(advertiser.peerID);
            expect(peerJid).to.equal(@"jid@localhost");
            done();
        }];
        [delegate browser:nil foundPeer:advertiser.peerID withDiscoveryInfo:@{@"jid": @"jid@localhost"}];
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
    __block MCPeerID *ownPeerID, *otherPeerID;
    __block NSDictionary *ownDiscoInfo, *otherDiscoInfo;
    __block id<MCNearbyServiceBrowserDelegate> delegate;
    beforeEach(^{
        ownPeerID = [[MCPeerID alloc] initWithDisplayName:@"own peer ID"];
        otherPeerID = [[MCPeerID alloc] initWithDisplayName:@"other peer ID"];
        ownDiscoInfo = @{@"jid": @"self@localhost"};
        otherDiscoInfo = @{@"jid": @"other@localhost"};
        peerList = [[WHPeerList alloc] initWithOwnPeerID:ownPeerID contactJids:[NSSet set]];
        delegate = (id)[peerList browser];
    });

    it(@"should initially be empty", ^{
        expect(peerList.peers).to.haveCountOf(0);
    });

    it(@"should not add own peer id", ^{
        [delegate browser:nil foundPeer:ownPeerID withDiscoveryInfo:ownDiscoInfo];
        expect(peerList.peers).to.haveCountOf(0);
    });

    it(@"should add a different peer id", ^{
        [delegate browser:nil foundPeer:otherPeerID withDiscoveryInfo:otherDiscoInfo];
        expect(peerList.peers).to.haveCountOf(1);
    });

    it(@"should not add duplicates", ^{
        [delegate browser:nil foundPeer:otherPeerID withDiscoveryInfo:otherDiscoInfo];
        [delegate browser:nil foundPeer:otherPeerID withDiscoveryInfo:otherDiscoInfo];
        expect(peerList.peers).to.haveCountOf(1);
    });

    it(@"should ignore existing contacts", ^{
        peerList = [[WHPeerList alloc] initWithOwnPeerID:ownPeerID
                                             contactJids:[NSSet setWithObject:@"other@localhost"]];
        delegate = (id)[peerList browser];
        [delegate browser:nil foundPeer:otherPeerID withDiscoveryInfo:otherDiscoInfo];
        expect(peerList.peers).to.haveCountOf(0);
    });

    it(@"should removed lost peer ids", ^{
        [delegate browser:nil foundPeer:otherPeerID withDiscoveryInfo:otherDiscoInfo];
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
        [delegate browser:nil foundPeer:otherPeerID withDiscoveryInfo:otherDiscoInfo];
    });
});

describe(@"WHKeyExchangePeer", ^{
    NSString *contactJid = @"contact@locahost";
    NSString *ownJid = @"ownjid@locahost";
    __block MCPeerID *ownPeerID, *otherPeerID;
    beforeEach(^{
        ownPeerID = [[MCPeerID alloc] initWithDisplayName:@"own display name"];
        otherPeerID = [[MCPeerID alloc] initWithDisplayName:@"other display name"];
    });

    WHKeyExchangePeer *(^peerWithBrowser)(id) = ^(id browser) {
        return [[WHKeyExchangePeer alloc] initWithOwnPeerID:ownPeerID
                                               remotePeerID:otherPeerID
                                                    peerJid:contactJid
                                                    browser:browser];
    };

    describe(@"outgoing connection", ^{
        it(@"should set its name to the remote peer's display name", ^{
            WHKeyExchangePeer *peer = peerWithBrowser(nil);
            expect(peer.name).to.equal(otherPeerID.displayName);
        });

        it(@"should ask the browser to connect to the peer", ^{
            id browser = [OCMockObject mockForClass:[WHMultipeerBrowser class]];
            [[[browser expect] andReturn:nil] connectToPeer:otherPeerID ownJid:ownJid];

            WHKeyExchangePeer *peer = peerWithBrowser(browser);
            [peer connectWithJid:ownJid];

            [browser verify];
        });

        it(@"should report an error when the connection is refused", ^AsyncBlock {
            id session = [OCMockObject mockForClass:[WHMultipeerSession class]];
            [[[session expect] andReturn:[RACSignal return:@NO]] connected];

            id browser = [OCMockObject mockForClass:[WHMultipeerBrowser class]];
            [[[browser expect] andReturn:session] connectToPeer:otherPeerID ownJid:ownJid];

            WHKeyExchangePeer *peer = peerWithBrowser(browser);
            [[peer connectWithJid:ownJid] subscribeError:^(NSError *error) {
                [session verify];
                done();
            }];
        });

        it(@"should create a new contact once the key exchange is complete", ^AsyncBlock{
            NSData *jid = [contactJid dataUsingEncoding:NSUTF8StringEncoding];
            NSData *keyBits = [WHKeyPair createKeyPairForJid:ownJid].publicKeyBits;
            WHKeyPair *globalKey = [WHKeyPair createOwnGlobalKeyPair];
            NSData *globalKeyBits = globalKey.publicKeyBits;
            NSData *globalSymmetricKey = globalKey.symmetricKey;
            SecItemDelete((__bridge CFDictionaryRef)@{(__bridge id)kSecClass: (__bridge id)kSecClassKey});
            [WHKeyPair createOwnGlobalKeyPair];

            RACSubject *incomingData = [RACReplaySubject subject];
            [incomingData sendNext:jid];
            [incomingData sendNext:globalKeyBits];
            [incomingData sendNext:globalSymmetricKey];
            [incomingData sendNext:keyBits];

            id session = [OCMockObject mockForClass:[WHMultipeerSession class]];
            [[session expect] sendData:isKindOfClass([NSData class])]; // global sign key
            [[session expect] sendData:isKindOfClass([NSData class])]; // global encryption key
            [[session expect] sendData:isKindOfClass([NSData class])]; // pair key

            [[[session expect] andReturn:[RACSignal return:@YES]] connected];
            [[[session expect] andReturn:incomingData] incomingData];

            id browser = [OCMockObject mockForClass:[WHMultipeerBrowser class]];
            [[[browser expect] andReturn:session] connectToPeer:otherPeerID ownJid:ownJid];

            WHKeyExchangePeer *peer = [[WHKeyExchangePeer alloc] initWithOwnPeerID:ownPeerID
                                                                      remotePeerID:otherPeerID
                                                                           peerJid:contactJid
                                                                           browser:browser];
            [[peer connectWithJid:ownJid] subscribeNext:^(Contact *contact) {
                expect(contact.name).to.equal(otherPeerID.displayName);
                expect(contact.ownKey).notTo.beNil();
                expect(contact.ownKey.publicKey).notTo.beNil();
                expect(contact.ownKey.privateKey).notTo.beNil();
                expect(contact.contactKey).notTo.beNil();
                expect(contact.contactKey.publicKey).notTo.beNil();
                expect(contact.contactKey.privateKey).to.beNil();

                WHKeyPair *globalKey = [WHKeyPair getGlobalKeyFromJid:contactJid];
                expect(globalKey.publicKey).notTo.beNil();
                expect(globalKey.symmetricKey).notTo.beNil();
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

            WHKeyExchangePeer *peer = [[WHKeyExchangePeer alloc] initWithOwnPeerID:ownPeerID
                                                                      remotePeerID:otherPeerID
                                                                           peerJid:contactJid
                                                                        invitation:handler];
            [peer connectWithJid:ownJid];
        });

        it(@"should be able to reject connections", ^AsyncBlock{
            invitationHandler handler = ^(BOOL accept, MCSession *session){
                expect(accept).to.beFalsy();
                expect(session).to.beNil();
                done();
            };

            WHKeyExchangePeer *peer = [[WHKeyExchangePeer alloc] initWithOwnPeerID:ownPeerID
                                                                      remotePeerID:otherPeerID
                                                                           peerJid:contactJid
                                                                        invitation:handler];
            [peer reject];
        });
    });
});

describe(@"WHMultipeerSession", ^{
    it(@"should send the current user's jid with connection requests", ^{
        NSString *ownJid = @"ownjid@localhost";
        MCPeerID *peerID = [[MCPeerID alloc] initWithDisplayName:@"contact display name"];
        id browser = [OCMockObject mockForClass:[MCNearbyServiceBrowser class]];
        [[[browser expect] andReturn:peerID] myPeerID];
        [[browser expect] invitePeer:peerID
                           toSession:OCMOCK_ANY
                         withContext:[ownJid dataUsingEncoding:NSUTF8StringEncoding]
                             timeout:0];

        (void)[[WHMultipeerSession alloc] initWithRemotePeerID:peerID ownJid:ownJid serviceBrowser:browser];
        [browser verify];
    });
});
SpecEnd
