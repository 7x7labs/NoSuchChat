//
//  Contact.h
//  whisper
//
//  Created by Thomas Goyne on 7/15/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "_Contact.h"

@interface Contact : _Contact
@property (nonatomic, strong) NSString *name;

+ (NSArray *)all;
+ (Contact *)createWithName:(NSString *)name;
@end
