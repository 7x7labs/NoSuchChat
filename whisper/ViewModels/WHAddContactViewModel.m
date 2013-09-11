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
#import "WHKeyExchangePeer.h"
#import "WHMultipeerManager.h"

#import <libextobjc/EXTScope.h>
#import <net/if.h>
#import <sys/ioctl.h>
#import <sys/socket.h>

@interface WHPotentialContactViewModel ()
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSURL *avatarURL;
@property (nonatomic) BOOL connecting;

@property (nonatomic, strong) WHKeyExchangePeer *peer;
@property (nonatomic, strong) NSString *jid;
@end

@implementation WHPotentialContactViewModel
- (instancetype)initWithPeer:(WHKeyExchangePeer *)peer {
    if (!(self = [super init])) return self;

    self.name = peer.name;
    self.avatarURL = [Contact avatarURLForEmail:peer.jid];
    self.peer = peer;
    self.jid = peer.jid;

    return self;
}

- (RACSignal *)connect {
    self.connecting = YES;
    return [[[self.peer connect]
            deliverOn:[RACScheduler mainThreadScheduler]]
            finally:^{
                self.connecting = NO;
            }];
}
@end

@interface WHAddContactViewModel ()
@property (nonatomic, strong) WHChatClient *client;
@property (nonatomic, strong) NSSet *contactJids;

@property (nonatomic) NSInteger count;
@property (nonatomic) BOOL advertising;

@property (nonatomic, strong) WHMultipeerManager *manager;
@property (nonatomic, strong) NSMutableDictionary *viewModels;
@property (nonatomic, strong) NSArray *peers;
@end

@implementation WHAddContactViewModel
- (instancetype)initWithClient:(WHChatClient *)client {
    if (!(self = [super init])) return self;

    self.client = client;
    self.manager = [[WHMultipeerManager alloc] initWithJid:self.client.jid
                                                      name:self.client.displayName];
    self.viewModels = [NSMutableDictionary new];

    RAC(self, contactJids) = [RACAbleWithStart(self.client, contacts) map:^(NSArray *contacts) {
        return [NSSet setWithArray:[contacts valueForKey:@"jid"]];
    }];

    @weakify(self)
    RAC(self, peers) = [RACAble(self, manager.peers)
                        map:^(NSArray *peers) {
                            return [[peers.rac_sequence
                                    filter:^BOOL(WHKeyExchangePeer *peer) {
                                        @strongify(self)
                                        return ![peer.jid isEqualToString:client.jid]
                                            && ![self.contactJids containsObject:peer.jid];
                                    }]
                                    array];
                        }];
    RAC(self, count) = [[RACAble(self, peers)
                        map:^id(NSArray *peers) { return @([peers count]); }]
                        deliverOn:[RACScheduler mainThreadScheduler]];

    RACBind(self.manager, advertising) = RACBind(self, advertising);

#ifdef DEBUG
    self.advertising = YES;
#else
    RAC(self, advertising) = [[[[[RACSignal return:RACUnit.defaultUnit]
                              concat:[RACSignal interval:1]]
                              map:^id(id _) {
                                  int sock = socket(PF_INET, SOCK_DGRAM, 0);
                                  if (sock == -1) {
                                      NSLog(@"Failed to open socket for ifflags %d: %s",
                                            errno, strerror(errno));
                                      return @YES;
                                  }

                                  @onExit { close(sock); };

                                  // SIOCSIFFLAGS seems to always set IFF_RUNNING,
                                  // but this seems to always fail iff wifi is
                                  // disabled and updates instantly
                                  struct ifreq ifr = { .ifr_name = "en0" };
                                  return @(ioctl(sock, SIOCGIFADDR, &ifr) != 0);
                              }]
                              distinctUntilChanged]
                              deliverOn:[RACScheduler mainThreadScheduler]];
#endif

    return self;
}

- (WHPotentialContactViewModel *)objectAtIndexedSubscript:(NSUInteger)index {
    WHKeyExchangePeer *peer = self.peers[index];
    if (!self.viewModels[peer.jid])
        self.viewModels[peer.jid] = [[WHPotentialContactViewModel alloc] initWithPeer:peer];
    return self.viewModels[peer.jid];
}

- (WHPotentialContactViewModel *)viewModelForPeer:(WHKeyExchangePeer *)peer {
    if (!self.viewModels[peer.jid])
        self.viewModels[peer.jid] = [[WHPotentialContactViewModel alloc] initWithPeer:peer];
    return self.viewModels[peer.jid];
}

- (RACSignal *)invitations {
    return self.manager.invitations;
}

- (void)dealloc {
    self.manager.advertising = NO;
}

@end
