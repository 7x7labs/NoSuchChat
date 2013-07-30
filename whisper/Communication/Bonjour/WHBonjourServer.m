//
//  WHBonjourServer.m
//  whisper
//
//  Created by Thomas Goyne on 7/22/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHBonjourServer.h"

@interface WHBonjourServer ()
@property (nonatomic, strong) NSNetService *netService;
@end

@implementation WHBonjourServer
- (instancetype)initWithName:(NSString *)name port:(uint16_t)port {
    self = [super init];
    if (!self) return self;

    self.netService = [[NSNetService alloc] initWithDomain:@"local."
                                                      type:@"_whisper._tcp."
                                                      name:name
                                                      port:port];

    [self.netService scheduleInRunLoop:[NSRunLoop currentRunLoop]
                               forMode:NSRunLoopCommonModes];
    [self.netService publish];

    return self;
}

- (void)dealloc {
    [self.netService stop];
    [self.netService removeFromRunLoop:[NSRunLoop currentRunLoop]
                               forMode:NSRunLoopCommonModes];
}
@end
