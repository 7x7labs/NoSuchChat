//
//  WHDiffieHellman.h
//  whisper
//
//  Created by Thomas Goyne on 8/26/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@interface WHDiffieHellman : NSObject
@property (nonatomic, readonly) int32_t ourKeyId;
@property (nonatomic, readonly) int32_t theirKeyId;
@property (nonatomic, readonly) NSData *publicKey;

+ (WHDiffieHellman *)createOutgoing;
+ (WHDiffieHellman *)createIncomingWithKey:(NSData *)keyData keyId:(int32_t)keyId;

- (WHDiffieHellman *)combineWith:(WHDiffieHellman *)other;

- (NSData *)encrypt:(NSData *)data iterations:(uint32_t)iteration;
- (NSData *)decrypt:(NSData *)data iterations:(uint32_t)iteration;
@end
