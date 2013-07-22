//
//  WHBonjourServerBrowser.h
//  whisper
//
//  Created by Thomas Goyne on 7/22/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSignal;

@interface WHBonjourServerBrowser : NSObject
- (RACSignal *)domainNames;
@end
