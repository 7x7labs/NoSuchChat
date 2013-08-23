//
//  WHDiffieHellman.h
//  whisper
//
//  Created by Thomas Goyne on 8/26/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@interface WHDiffieHellman : NSObject
@property (nonatomic, readonly) NSData *publicKey;

- (void)setOtherPublic:(NSData *)otherPublic;

- (NSData *)encrypt:(NSData *)data;
- (NSData *)decrypt:(NSData *)data;
@end
