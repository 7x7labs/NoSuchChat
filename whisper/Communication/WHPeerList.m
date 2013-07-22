//
//  WHPeerList.m
//  whisper
//
//  Created by Thomas Goyne on 7/22/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHPeerList.h"

#import "WHBonjourServer.h"
#import "WHBonjourServerBrowser.h"
#import "WHKeyExchangeClient.h"
#import "WHKeyExchangePeer.h"
#import "WHKeyExchangeServer.h"

#import <EXTScope.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface WHPeerList ()
@property (nonatomic, strong) NSMutableArray *peers;

@property (nonatomic, strong) WHBonjourServer *bonjourServer;
@property (nonatomic, strong) WHBonjourServerBrowser *bonjourServerBrowser;
@property (nonatomic, strong) WHKeyExchangeServer *keyExchangeServer;
@end

@implementation WHPeerList
- (instancetype)init {
    self = [super init];
    if (!self) return self;

    self.peers = [NSMutableArray array];
    self.bonjourServerBrowser = [WHBonjourServerBrowser new];
    self.keyExchangeServer = [WHKeyExchangeServer new];
    self.bonjourServer = [[WHBonjourServer alloc] initWithName:@"???"
                                                          port:self.keyExchangeServer.port];

    @weakify(self);
    void (^addPeer)(WHKeyExchangePeer *peer) = ^(WHKeyExchangePeer *peer) {
        @strongify(self);
        [self.peers addObject:peer];
    };

    [self.keyExchangeServer.clients subscribeNext:addPeer];

    [self.bonjourServerBrowser.domainNames subscribeNext:^(NSString *domain) {
        WHKeyExchangeClient *client = [[WHKeyExchangeClient alloc] initWithDomain:domain port:0];
        [client.peer subscribeNext:addPeer];
    }];

    return self;
}
@end
