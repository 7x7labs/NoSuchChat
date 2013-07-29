//
//  WHCoreData.h
//  whisper
//
//  Created by Thomas Goyne on 7/15/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class RACSignal;

@interface WHCoreData : NSObject
+ (NSManagedObjectContext *)managedObjectContext;
+ (NSManagedObjectContext *)backgroundManagedObjectContext;

+ (RACSignal *)modifyObject:(NSManagedObject *)object
                  withBlock:(void (^)(NSManagedObject *))block;

+ (RACSignal *)insertObjectOfType:(NSString *)type
                        withBlock:(void (^)(NSManagedObject *))block;

+ (void)initTestContext;
+ (void)initSqliteContext;
@end
