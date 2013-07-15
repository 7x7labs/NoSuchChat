//
//  WHCoreData.m
//  whisper
//
//  Created by Thomas Goyne on 7/15/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHCoreData.h"

static NSManagedObjectContext *managedObjectContext;

@implementation WHCoreData
+ (NSManagedObjectContext *)managedObjectContext {
    return managedObjectContext;
}

+ (void)initWithType:(NSString *)storeType URL:(NSURL *)storeUrl {
    NSManagedObjectModel *objectModel = [NSManagedObjectModel mergedModelFromBundles:nil];

    NSPersistentStoreCoordinator *coordinator =
        [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:objectModel];

	NSError *error;
    if (![coordinator addPersistentStoreWithType:storeType
                                   configuration:nil
                                             URL:storeUrl
                                         options:nil
                                           error:&error])
        NSLog(@"Error opening persisted core data: %@", error);

    for (NSManagedObject *ct in [managedObjectContext registeredObjects])
        [managedObjectContext deleteObject:ct];

    managedObjectContext = [NSManagedObjectContext new];
    [managedObjectContext setPersistentStoreCoordinator:coordinator];
}

+ (void)initSqliteContext {
    [self initWithType:NSSQLiteStoreType
                   URL:[NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingString:@"/data.sqlite"]]];
}

+ (void)initTestContext {
    [self initWithType:NSInMemoryStoreType
                   URL:nil];
}
@end
