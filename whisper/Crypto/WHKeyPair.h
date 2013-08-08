//
//  WHKeyPair.h
//  whisper
//
//  Created by Thomas Goyne on 7/18/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WHKeyPair : NSObject
@property (nonatomic, readonly) SecKeyRef publicKey;
@property (nonatomic, readonly) SecKeyRef privateKey;
@property (nonatomic, readonly) NSData *publicKeyBits;
@property (nonatomic, readonly) NSData *symmetricKey;

+ (WHKeyPair *)createKeyPairForJid:(NSString *)jid;
+ (WHKeyPair *)getOwnKeyPairForJid:(NSString *)jid;

+ (WHKeyPair *)createOwnGlobalKeyPair;
+ (WHKeyPair *)getOwnGlobalKeyPair;

+ (WHKeyPair *)addKey:(NSData *)key fromJid:(NSString *)jid;
+ (WHKeyPair *)getKeyFromJid:(NSString *)jid;

+ (WHKeyPair *)addGlobalKey:(NSData *)key fromJid:(NSString *)jid;
+ (void)addSymmetricKey:(NSData *)key fromJid:(NSString *)jid;
+ (WHKeyPair *)getGlobalKeyFromJid:(NSString *)jid;
@end
