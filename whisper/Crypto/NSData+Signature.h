//
//  NSData+Signature.h
//  whisper
//
//  Created by Thomas Goyne on 7/18/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@interface NSData (Signature)
- (NSData *)wh_sign:(SecKeyRef)key;
- (BOOL)wh_verify:(SecKeyRef)key;
@end
