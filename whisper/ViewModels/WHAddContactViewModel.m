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
    return [[WHPotentialContactViewModel alloc] initWithPeer:self.peerList.peers[index]
                                                         jid:self.client.jid];
}

- (void)dealloc {
    self.client.advertising = NO;
}

@end
