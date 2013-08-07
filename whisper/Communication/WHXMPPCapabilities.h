//
//  WHXMPPCapabilities.h
//  whisper
//
//  Created by Thomas Goyne on 8/7/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class XMPPStream;

@interface WHXMPPCapabilities : NSObject
- (instancetype)initWithStream:(XMPPStream *)stream;
@end
