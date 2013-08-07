//
//  WHKeyExchangePeer.m
//  whisper
//
//  Created by Thomas Goyne on 7/23/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHKeyExchangePeer.h"

#import "Contact.h"
#import "WHError.h"
#import "WHKeyPair.h"
#import "WHMultipeerBrowser.h"
#import "WHMultipeerSession.h"

@interface RACSignal (WHNext)
- (instancetype)next:(id (^)(id value))block;
@end

@implementation RACSignal (WHNext)
- (instancetype)next:(id (^)(id))block {
    Class class = self.class;

    return [[self bind:^{
        __block BOOL first = YES;

        return ^(id value, BOOL *stop) {
            if (first) {
                first = NO;
                id ret = block(value);
                if ([ret isKindOfClass:[NSError class]])
                    return [class error:ret];
                return ret ? [class return:ret] : [class empty];
            }

            return [class return:value];
        };
    }] setNameWithFormat:@"[%@] -next:", self.name];
}
@end

@interface WHKeyExchangePeer ()
@property (nonatomic, strong) NSString *name;

@property (nonatomic, strong) MCPeerID *ownPeerID;
@property (nonatomic, strong) MCPeerID *remotePeerID;
@property (nonatomic, strong) WHMultipeerBrowser *browser;
@property (nonatomic, strong) invitationHandler invitation;
@end

@implementation WHKeyExchangePeer
- (instancetype)initWithOwnPeerID:(MCPeerID *)ownPeerID
                     remotePeerID:(MCPeerID *)remotePeerID
{
    if (!(self = [super init])) return self;
    self.name = remotePeerID.displayName;
    self.ownPeerID = ownPeerID;
    self.remotePeerID = remotePeerID;
    return self;
}

- (instancetype)initWithOwnPeerID:(MCPeerID *)ownPeerID
                     remotePeerID:(MCPeerID *)remotePeerID
                          browser:(WHMultipeerBrowser *)browser
{
    if (!(self = [self initWithOwnPeerID:ownPeerID remotePeerID:remotePeerID])) return nil;
    self.browser = browser;
    return self;
}

- (instancetype)initWithOwnPeerID:(MCPeerID *)ownPeerID
                     remotePeerID:(MCPeerID *)remotePeerID
                    invitation:(invitationHandler)invitation
{
    if (!(self = [self initWithOwnPeerID:ownPeerID remotePeerID:remotePeerID])) return nil;
    self.invitation = invitation;
    return self;
}

- (RACSignal *)connectWithJid:(NSString *)jid {
    NSAssert(!!self.browser != !!self.invitation,
             @"WHKeyExchangePeer needs a service browser or invitation handler to connect");

    WHMultipeerSession *session;
    if (self.browser)
        session = [self.browser connectToPeer:self.remotePeerID];
    else
        session = [[WHMultipeerSession alloc] initWithSelf:self.ownPeerID
                                                    remote:self.remotePeerID
                                                invitation:self.invitation];

    __block BOOL called = NO;
    __block NSString *contactJid = nil;
    return [[[[[session.connected
            flattenMap:^RACStream *(NSNumber *didConnect) {
                assert(!called);
                called = YES;
                if (![didConnect boolValue])
                    return [WHError errorSignalWithDescription:@"Peer refused connection"];
                NSError *error = [session sendData:[jid dataUsingEncoding:NSUTF8StringEncoding]];
                return error ? [RACSignal error:error] : [session.incomingData take:3];
            }]
            next:^(NSData *jidData) {
                contactJid = [[NSString alloc] initWithData:jidData encoding:NSUTF8StringEncoding];
                return [session sendData:[WHKeyPair getOwnGlobalKeyPair].publicKeyBits];
            }]
            next:^(NSData *globalKey) {
                [WHKeyPair addGlobalKey:globalKey fromJid:contactJid];
                return [session sendData:[WHKeyPair createKeyPairForJid:contactJid].publicKeyBits];
            }]
            deliverOn:[RACScheduler mainThreadScheduler]]
            next:^(NSData *publicKey) {
                [WHKeyPair addKey:publicKey fromJid:contactJid];
                return [Contact createWithName:self.name jid:contactJid];
            }];
}

- (void)reject {
    NSAssert(self.invitation, @"Can only reject incoming connections");
    self.invitation(NO, nil);
    self.invitation = nil;
}
@end
