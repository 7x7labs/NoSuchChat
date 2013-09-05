//
//  WHMultipeerPacket.h
//  whisper
//
//  Created by Thomas Goyne on 9/9/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import <Mantle/Mantle.h>

typedef enum  WHPacketMessage : int32_t {
    WHPMSendDhKey,
    WHPMReject,

    WHPMSendPublicKey,
    WHPMSendGlobalPublicKey,
    WHPMSendSymmetricKey,

    WHPMRequestPublicKey,
    WHPMRequestGlobalPublicKey,
    WHPMRequestSymmetricKey
} WHPacketMessage;

@interface WHMultipeerPacket : MTLModel
@property (nonatomic) int32_t version;
@property (nonatomic) WHPacketMessage message;
@property (nonatomic) int32_t senderKeyId;
@property (nonatomic) int32_t receiverKeyId;
@property (nonatomic) uint32_t keyIterations;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) NSData *checksum;

+ (NSData *)serialize:(NSData *)data
              message:(WHPacketMessage)message
          senderKeyId:(int32_t)senderKeyId
        receiverKeyId:(int32_t)receiverKeyId
        keyIterations:(uint32_t)keyIterations;
+ (WHMultipeerPacket *)deserialize:(NSData *)data;
@end
