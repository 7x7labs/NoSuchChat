//
//  NSData+Encryption.h
//  whisper
//
//  Created by Thomas Goyne on 7/20/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (Encryption)
+ (NSData *)wh_createSessionKey;

- (NSData *)wh_AES256EncryptWithKey:(NSData *)key;
- (NSData *)wh_AES256DecryptWithKey:(NSData *)key;

- (NSData *)wh_encryptWithKey:(SecKeyRef)key;
- (NSData *)wh_decryptWithKey:(SecKeyRef)key;
@end
