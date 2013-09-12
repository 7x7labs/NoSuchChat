//
//  WHKeyExchangePeer.h
//  whisper
//
//  Created by Thomas Goyne on 7/23/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class WHMultipeerManager;
@class WHMultipeerSession;

@interface WHKeyExchangePeer : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *jid;
@property (nonatomic, readonly) BOOL wantsToConnect;

- (RACSignal *)connect;
- (void)reject;
@end

@interface WHKeyExchangePeer (Manager)
@property (nonatomic, readonly) BOOL hasSessions;

- (void)addSession:(WHMultipeerSession *)session;
- (void)removeSession:(WHMultipeerSession *)session;
@end
