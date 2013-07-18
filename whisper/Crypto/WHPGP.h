//
//  WHPGP.h
//  whisper
//
//  Created by Thomas Goyne on 7/18/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@class WHKeyPair;

@interface WHPGP : NSObject
- (NSData *)encrypt:(NSString *)string
          senderKey:(WHKeyPair *)senderKey
        receiverKey:(WHKeyPair *)receiverKey;

- (NSString *)decrypt:(NSData *)data
            senderKey:(WHKeyPair *)senderKey
          receiverKey:(WHKeyPair *)receiverKey;
@end
