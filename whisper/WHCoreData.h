//
//  WHCoreData.h
//  whisper
//
//  Created by Thomas Goyne on 7/15/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WHCoreData : NSObject
+ (NSManagedObjectContext *)managedObjectContext;

+ (void)initTestContext;
+ (void)initSqliteContext;
@end
