//
//  WHKeyExchangePeer.m
//  whisper
//
//  Created by Thomas Goyne on 7/23/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHKeyExchangePeer.h"

#import "Contact.h"
#import "WHKeyExchangeClient.h"
#import "WHKeyExchangeServer.h"
#import "WHKeyPair.h"

#import <EXTScope.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface WHKeyExchangePeer ()
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *jid;
@property (nonatomic, strong) WHKeyExchangeClient *client;
@property (nonatomic) BOOL wantsToConnect;
@property (nonatomic) BOOL keySent;
@property (nonatomic, strong) RACSignal *connected;
@end

@implementation WHKeyExchangePeer
- (instancetype)initWithName:(NSString *)name
                         jid:(NSString *)jid
                      client:(WHKeyExchangeClient *)client
{
    self = [super init];
    if (!self) return self;

    self.name = name;
    self.jid = jid;
    self.client = client;

    [client.publicKey subscribeNext:^(NSData *key) {
        [WHKeyPair addKey:key fromJid:self.jid];
        self.wantsToConnect = YES;
    } error:^(NSError *error) {
        NSLog(@"error: %@", error);
    }];

    @weakify(self);
    self.connected = [[[[RACSignal
                      combineLatest:@[RACAble(self, wantsToConnect), RACAble(self, keySent)]
                      reduce:^(BOOL received, BOOL sent) { return @(received && sent); }]
                      filter:^BOOL(NSNumber *value) { return [value boolValue]; }]
                      take:1]
                      map:^(id _) {
                          @strongify(self);
                          return [Contact createWithName:self.name jid:self.jid];
                      }];
    return self;
}

- (void)connect {
    [self.client sendKey:[WHKeyPair createKeyPairForJid:self.jid].publicKeyBits];
    self.keySent = YES;
}
@end
