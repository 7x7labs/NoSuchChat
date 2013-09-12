//
//  WHKeyExchangePeer.m
//  whisper
//
//  Created by Thomas Goyne on 7/23/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHKeyExchangePeer.h"

#import "Contact.h"
#import "WHDiffieHellman.h"
#import "WHError.h"
#import "WHKeyPair.h"
#import "WHMultipeerSession.h"
#import "WHMultipeerPacket.h"

#import <libextobjc/EXTScope.h>

@interface WHKeyExchangePeer ()
@property (nonatomic) BOOL wantsToConnect;

@property (nonatomic, strong) NSMutableDictionary *sessions;
@property (nonatomic, strong) RACSubject *connection;

@property (nonatomic, strong) NSArray *incomingKeys;
@property (nonatomic, strong) NSArray *outgoingKeys;
@property (nonatomic, strong) NSArray *combinedKeys;
@property (nonatomic) uint32_t keyIterations;

@property (nonatomic, strong) NSData *publicKey;
@property (nonatomic, strong) NSData *globalPublicKey;
@property (nonatomic, strong) NSData *symmetricKey;

@property (nonatomic, strong) NSMutableArray *bufferedPackets;
@property (nonatomic) BOOL complete;
@end

@implementation WHKeyExchangePeer
- (instancetype)init {
    self = [super init];

    self.sessions = [NSMutableDictionary new];

    self.incomingKeys = @[];
    self.outgoingKeys = @[];
    self.combinedKeys = @[];

    self.bufferedPackets = [NSMutableArray array];

    return self;
}

- (void)addSession:(WHMultipeerSession *)session {
    self.sessions[session.peerID] = session;
    [self rac_liftSelector:@selector(receive:)
      withObjectsFromArray:@[session.incomingData]];
}

- (void)removeSession:(WHMultipeerSession *)session {
    [self.sessions removeObjectForKey:session.peerID];
}

- (BOOL)hasSessions {
    return [self.sessions count] > 0;
}

- (void)receive:(NSData *)data {
    WHMultipeerPacket *packet = [WHMultipeerPacket deserialize:data];
    if (packet)
        [self process:packet];
}

- (void)process:(WHMultipeerPacket *)packet {
    // MCSessionSendDataReliable claims to guarantee in-order deliver, but that
    // isn't actually true so we may sometimes get a packet that uses a key
    // before we receive the key.
    if (packet.message > WHPMReject && packet.senderKeyId > [[self.incomingKeys lastObject] theirKeyId]) {
        [self.bufferedPackets addObject:packet];
        return;
    }

    switch (packet.message) {
        case WHPMSendDhKey:
            self.incomingKeys = [self.incomingKeys arrayByAddingObject:[WHDiffieHellman createIncomingWithKey:packet.data keyId:packet.senderKeyId]];

            if ([self.outgoingKeys count]) {
                // We've sent a key, but they don't have it, so resend it
                if (packet.receiverKeyId == 0)
                    [self send:[[self.outgoingKeys lastObject] publicKey] message:WHPMSendDhKey];
                [self maybeConnect];
            }
            else {
                self.wantsToConnect = YES;
            }

            if ([self.bufferedPackets count]) {
                NSArray *packets = self.bufferedPackets;
                self.bufferedPackets = [NSMutableArray array];
                for (WHMultipeerPacket *bufferedPacket in packets)
                    [self process:bufferedPacket];
            }

            break;

        case WHPMReject: {
            NSString *message = [NSString stringWithFormat:@"%@ declined the connection.", self.name];
            [self.connection sendError:[WHError errorWithDescription:message]];
            [self cleanup];
            break;
        }


        case WHPMRequestGlobalPublicKey:
            NSLog(@"%p: Got request for our global public key", self);
            [self send:[WHKeyPair getOwnGlobalKeyPair].publicKeyBits
               message:WHPMSendGlobalPublicKey];
            break;

        case WHPMRequestPublicKey:
            NSLog(@"%p: Got request for our public key", self);
            [self send:[WHKeyPair createKeyPairForJid:self.jid].publicKeyBits
               message:WHPMSendPublicKey];
            break;

        case WHPMRequestSymmetricKey:
            NSLog(@"%p: Got request for our symmetric key", self);
            [self send:[WHKeyPair getOwnGlobalKeyPair].symmetricKey
               message:WHPMSendSymmetricKey];
            break;


        case WHPMSendGlobalPublicKey:
            NSLog(@"%p: Got global public key", self);
            self.globalPublicKey = [self decrypt:packet];
            [self checkComplete];
            break;

        case WHPMSendPublicKey:
            NSLog(@"%p: Got public key", self);
            self.publicKey = [self decrypt:packet];
            [self checkComplete];
            break;

        case WHPMSendSymmetricKey:
            NSLog(@"%p: Got symmetric key", self);
            self.symmetricKey = [self decrypt:packet];
            [self checkComplete];
            break;
    }
}

- (WHDiffieHellman *)combinedForOurId:(int32_t)ourId theirId:(int32_t)theirId {
    WHDiffieHellman *dh = [[self.combinedKeys.rac_sequence
                           filter:^BOOL(WHDiffieHellman *combined) {
                               return combined.ourKeyId == ourId &&
                                      combined.theirKeyId == theirId;
                           }] head];
    if (dh) return dh;

    // We haven't seen this combination of DH keys before, so try to assemble
    // the secret from the data we have
    WHDiffieHellman *ourKey = [self.outgoingKeys.rac_sequence
                               objectPassingTest:^BOOL(WHDiffieHellman *value) {
                                   return value.ourKeyId == ourId;
                               }];
    WHDiffieHellman *theirKey = [self.incomingKeys.rac_sequence
                                 objectPassingTest:^BOOL(WHDiffieHellman *value) {
                                     return value.theirKeyId == theirId;
                                 }];
    NSAssert(ourKey && theirKey, @"Invalid DH key IDs");
    if (!ourKey || !theirKey) return nil;

    dh = [ourKey combineWith:theirKey];
    self.combinedKeys = [self.combinedKeys arrayByAddingObject:dh];
    return dh;
}

- (NSData *)decrypt:(WHMultipeerPacket *)packet {
    WHDiffieHellman *dh = [self combinedForOurId:packet.receiverKeyId theirId:packet.senderKeyId];

    // Throw away all keys older than this one
    self.outgoingKeys = [[self.outgoingKeys.rac_sequence filter:^BOOL(WHDiffieHellman *key) {
        return key.ourKeyId >= dh.ourKeyId;
    }] array];
    self.incomingKeys = [[self.incomingKeys.rac_sequence filter:^BOOL(WHDiffieHellman *key) {
        return key.theirKeyId >= dh.theirKeyId;
    }] array];
    self.combinedKeys = [[self.combinedKeys.rac_sequence
                         filter:^BOOL(WHDiffieHellman *key) {
                             return key.ourKeyId >= dh.ourKeyId &&
                                    key.theirKeyId >= dh.theirKeyId;
                         }]
                         array];

    NSData *decrypted = [dh decrypt:packet.data iterations:packet.keyIterations];
    NSLog(@"Data length: %d", (int)[decrypted length]);
    return decrypted;
}

- (void)send:(NSData *)data message:(WHPacketMessage)message {
    ++self.keyIterations;
    if (message == WHPMSendDhKey) {
        data = [WHMultipeerPacket serialize:data
                                    message:message
                                senderKeyId:[[self.outgoingKeys lastObject] ourKeyId]
                              receiverKeyId:[[self.incomingKeys lastObject] theirKeyId]
                              keyIterations:self.keyIterations];
    }
    else if (data) {
        int32_t ourKeyId = [[self.outgoingKeys firstObject] ourKeyId];
        int32_t theirKeyId = [[self.incomingKeys lastObject] theirKeyId];
        WHDiffieHellman *dh = [self combinedForOurId:ourKeyId theirId:theirKeyId];
        data = [WHMultipeerPacket serialize:[dh encrypt:data iterations:self.keyIterations]
                                    message:message
                                senderKeyId:ourKeyId
                              receiverKeyId:theirKeyId
                              keyIterations:self.keyIterations];
    }
    else {
        data = [WHMultipeerPacket serialize:data message:message senderKeyId:0 receiverKeyId:0 keyIterations:0];
    }

    @weakify(self)
    NSLog(@"%p: Sending %d to %@", self, message, self.jid);
    [[[[[[RACAbleWithStart(self, sessions)
     flattenMap:^RACStream *(NSMutableDictionary *sessions) {
         return sessions.rac_valueSequence.signal;
     }]
     map:^(WHMultipeerSession *session) {
         NSError *error = [session sendData:data];
         if (!error) return @YES;
         NSLog(@"Error sending data: %@", error);
         return @NO;
     }]
     filter:^BOOL(NSNumber *didSend) { return [didSend boolValue]; }]
     take:1]
     timeout:30]
     subscribeError:^(NSError *error) {
         @strongify(self)
         [self.connection sendError:error];
     }
     completed:^{
         @strongify(self)
         NSLog(@"%p: Completed send of %d", self, message);
     }];
}

- (void)checkComplete {
    if (!self.publicKey) return;
    if (!self.globalPublicKey) return;
    if (!self.symmetricKey) return;
    if (self.complete) return;

    NSLog(@"%p: Got all keys", self);
    self.complete = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"%p: Adding keys", self);
        [WHKeyPair addGlobalKey:self.globalPublicKey fromJid:self.jid];
        [WHKeyPair addSymmetricKey:self.symmetricKey fromJid:self.jid];
        [WHKeyPair addKey:self.publicKey fromJid:self.jid];

        NSLog(@"%p: Creating contact", self);
        [self.connection sendNext:[Contact createWithName:self.name jid:self.jid]];
        [self.connection sendCompleted];

        [self cleanup];
    });
}

- (void)maybeConnect {
    if (!self.complete && [self.incomingKeys count] && [self.outgoingKeys count]) {
        [self send:nil message:WHPMRequestGlobalPublicKey];
        [self send:nil message:WHPMRequestPublicKey];
        [self send:nil message:WHPMRequestSymmetricKey];
    }
}

- (void)reject {
    NSLog(@"%p: Rejecting %@", self, self.jid);
    [self send:nil message:WHPMReject];
    [self cleanup];
}

- (void)cleanup {
    NSLog(@"Deleting DH keys");
    self.wantsToConnect = NO;
    self.incomingKeys = @[];
    self.outgoingKeys = @[];
    self.combinedKeys = @[];
    self.publicKey = nil;
    self.globalPublicKey = nil;
    self.symmetricKey = nil;
}

- (RACSignal *)connect {
    NSLog(@"%p: Beginning key exchange with %@", self, self.jid);
    self.connection = [RACReplaySubject replaySubjectWithCapacity:1];
    self.outgoingKeys = [self.outgoingKeys arrayByAddingObject:[WHDiffieHellman createOutgoing]];
    [self send:[[self.outgoingKeys lastObject] publicKey] message:WHPMSendDhKey];
    [self maybeConnect];
    return self.connection;
}

@end
