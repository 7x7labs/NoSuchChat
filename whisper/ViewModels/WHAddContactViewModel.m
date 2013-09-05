//
//  WHAddContactViewModel.m
//  whisper
//
//  Created by Thomas Goyne on 9/4/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHAddContactViewModel.h"

#import "Contact.h"
#import "WHChatClient.h"
#import "WHPeerList.h"
#import "WHKeyExchangePeer.h"

#import <libextobjc/EXTScope.h>
#import <Reachability/Reachability.h>

#ifdef DEBUG
#define ALLOW_WIFI 1
#else
#define ALLOW_WIFI 0
#endif

@interface WHPotentialContactViewModel ()
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSURL *avatarURL;
@property (nonatomic) BOOL connecting;

@property (nonatomic, strong) WHKeyExchangePeer *peer;
@property (nonatomic, strong) NSString *jid;
@end

@implementation WHPotentialContactViewModel
- (instancetype)initWithPeer:(WHKeyExchangePeer *)peer jid:(NSString *)jid {
    if (!(self = [super init])) return self;

    self.name = peer.name;
    self.avatarURL = [Contact avatarURLForEmail:peer.peerJid];
    self.peer = peer;
    self.jid = jid;

    return self;
}

- (RACSignal *)connect {
    self.connecting = YES;
    return [[[self.peer connectWithJid:self.jid]
            deliverOn:[RACScheduler mainThreadScheduler]]
            finally:^{
                self.connecting = NO;
            }];
}
@end

@interface WHAddContactViewModel ()
@property (nonatomic, strong) WHChatClient *client;
@property (nonatomic, strong) NSArray *contacts;

@property (nonatomic, strong) WHPeerList *peerList;
@property (nonatomic, strong) Reachability *reach;
@property (nonatomic) BOOL advertising;
@end

@implementation WHAddContactViewModel
- (instancetype)initWithClient:(WHChatClient *)client contacts:(NSArray *)contacts {
    if (!(self = [super init])) return self;

    self.client = client;
    self.contacts = contacts;

    RAC(self, count) = [RACAble(self, peerList.peers) map:^id(NSArray *peers) {
        return @([peers count]);
    }];

    @weakify(self)
    RAC(self, peerList) = [RACAble(self.client, peerID) map:^id(MCPeerID *peerID) {
        if (!peerID) return nil;
        @strongify(self)
        return [[WHPeerList alloc] initWithOwnPeerID:peerID
                                         contactJids:[NSSet setWithArray:[self.contacts valueForKey:@"jid"]]];
    }];

    RACBind(self.client, advertising) = RACBind(self, advertising);

    self.reach = [Reachability reachabilityForLocalWiFi];
    self.reach.reachableOnWWAN = NO;

    self.reach.reachableBlock = ^(Reachability *_) {
        @strongify(self);
        self.advertising = ALLOW_WIFI;
    };

    self.reach.unreachableBlock = ^(Reachability *_) {
        @strongify(self)
        self.advertising = YES;
    };

    [self.reach startNotifier];
    self.advertising = ALLOW_WIFI || ![self.reach isReachableViaWiFi];

    return self;
}

- (WHPotentialContactViewModel *)objectAtIndexedSubscript:(NSUInteger)index {
    return [[WHPotentialContactViewModel alloc] initWithPeer:self.peerList.peers[index]
                                                         jid:self.client.jid];
}

- (void)dealloc {
    self.client.advertising = NO;
}

@end
