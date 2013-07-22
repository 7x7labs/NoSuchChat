//
//  WHKeyExchangePeer.m
//  whisper
//
//  Created by Thomas Goyne on 7/23/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHKeyExchangePeer.h"

#import "WHKeyExchangeClient.h"
#import "WHKeyExchangeServer.h"
#import "WHKeyPair.h"

#import <ReactiveCocoa/ReactiveCocoa.h>

@interface WHKeyExchangePeer ()
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *jid;
@property (nonatomic, strong) WHKeyExchangeClient *client;
@property (nonatomic) BOOL wantsToConnect;
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

    return self;
}

- (void)connect {
    WHKeyPair *kp = [WHKeyPair createKeyPairForJid:self.jid];
    [self.client sendKey:kp.publicKeyBits];
}
@end
