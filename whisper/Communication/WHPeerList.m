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

@property (nonatomic, strong) NSData *introData;
@property (nonatomic, strong) WHBonjourServer *bonjourServer;
@property (nonatomic, strong) WHBonjourServerBrowser *bonjourServerBrowser;
@property (nonatomic, strong) WHKeyExchangeServer *keyExchangeServer;
@end

@implementation WHPeerList
- (instancetype)initWithInfo:(NSDictionary *)info {
    self = [super init];
    if (!self) return self;

    self.peers = [NSMutableArray array];
    self.introData = [NSJSONSerialization dataWithJSONObject:info options:0 error:nil];
    self.bonjourServerBrowser = [WHBonjourServerBrowser new];
    self.keyExchangeServer = [[WHKeyExchangeServer alloc] initWithIntroData:self.introData];
    self.bonjourServer = [[WHBonjourServer alloc] initWithName:info[@"name"]
                                                          port:self.keyExchangeServer.port];

    @weakify(self);
    void (^addPeer)(WHKeyExchangePeer *peer) = ^(WHKeyExchangePeer *peer) {
        @strongify(self);
        [self.peers addObject:peer];
    };

    [self.keyExchangeServer.clients subscribeNext:addPeer];

    [self.bonjourServerBrowser.netServices subscribeNext:^(NSNetService *service) {
        WHKeyExchangeClient *client = [[WHKeyExchangeClient alloc]
                                       initWithDomain:[service domain]
                                       port:[service port]
                                       introData:self.introData];
        [client.peer subscribeNext:addPeer];
    }];

    return self;
}
@end
