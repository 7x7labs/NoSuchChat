//
//  WHMultipeerPacket.m
//  whisper
//
//  Created by Thomas Goyne on 9/9/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHMultipeerPacket.h"

#import "NSData+SHA.h"

@implementation WHMultipeerPacket
+ (NSData *)serialize:(NSData *)data
              message:(WHPacketMessage)message
          senderKeyId:(int32_t)senderKeyId
        receiverKeyId:(int32_t)receiverKeyId
        keyIterations:(uint32_t)keyIterations
{
    WHMultipeerPacket *packet = [WHMultipeerPacket new];
    packet.message = message;
    packet.senderKeyId = senderKeyId;
    packet.receiverKeyId = receiverKeyId;
    packet.keyIterations = keyIterations;
    packet.data = data;
    packet.checksum = [data sha256];
    return [NSKeyedArchiver archivedDataWithRootObject:packet];
}

+ (WHMultipeerPacket *)deserialize:(NSData *)data {
    WHMultipeerPacket *packet = [NSKeyedUnarchiver unarchiveObjectWithData:data];

    if (![packet isKindOfClass:[WHMultipeerPacket class]]) {
        NSAssert(NO, @"Expected WHPacket, got %@", packet);
        return nil;
    }
    if (packet.version != 0) {
        NSLog(@"Unsupported packet version %@", packet);
        return nil;
    }
    if ((packet.data || packet.checksum) && ![[packet.data sha256] isEqualToData:packet.checksum]) {
        NSAssert(NO, @"WHPacket checksum failed");
        return nil;
    }

    return packet;
}
@end
