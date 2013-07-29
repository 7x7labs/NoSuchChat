//
//  WHCoreData.m
//  whisper
//
//  Created by Thomas Goyne on 7/15/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHCoreData.h"

#import <ReactiveCocoa/ReactiveCocoa.h>

@interface WHCoreData ()
@property (nonatomic, strong) NSManagedObjectContext *mainThreadContext;
@property (nonatomic, strong) NSManagedObjectContext *backgroundContext;
@end

static WHCoreData *instance() {
    static WHCoreData *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [WHCoreData new]; });
    return instance;
}

@implementation WHCoreData
- (void)initWithType:(NSString *)storeType URL:(NSURL *)storeUrl {
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

    for (NSManagedObject *ct in [self.mainThreadContext registeredObjects])
        [self.mainThreadContext deleteObject:ct];

    self.mainThreadContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    self.mainThreadContext.persistentStoreCoordinator = coordinator;
    self.mainThreadContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy;

    self.backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    self.backgroundContext.parentContext = self.mainThreadContext;
    self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
}

+ (NSManagedObjectContext *)managedObjectContext {
    return instance().mainThreadContext;
}

+ (NSManagedObjectContext *)backgroundManagedObjectContext {
    return instance().backgroundContext;
}

+ (void)initSqliteContext {
    [instance() initWithType:NSSQLiteStoreType
                         URL:[NSURL fileURLWithPath:[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingString:@"/data.sqlite"]]];
}

+ (void)initTestContext {
    [instance() initWithType:NSInMemoryStoreType URL:nil];
}

+ (RACSignal *)modifyObject:(NSManagedObject *)object
                  withBlock:(void (^)(NSManagedObject *))block
{
    block(object);

    NSManagedObjectID *objectId = object.objectID;
    return [instance() runWithContext:^(NSManagedObjectContext *context) {
        NSManagedObject *localObject = [context objectWithID:objectId];
        block(localObject);
        return localObject;
    }];
}

+ (RACSignal *)insertObjectOfType:(NSString *)type
                        withBlock:(void (^)(NSManagedObject *))block
{
    return [instance() runWithContext:^(NSManagedObjectContext *context) {
        NSManagedObject *obj = [NSEntityDescription insertNewObjectForEntityForName:type
                                                             inManagedObjectContext:context];
        block(obj);
        return obj;
    }];
}

- (RACSignal *)runWithContext:(id (^)(NSManagedObjectContext *))block {
    RACSubject *subject = [RACReplaySubject subject];
    [self.backgroundContext performBlock:^{
        id obj = block(self.backgroundContext);

        NSError *error;
        if ([self.backgroundContext hasChanges] && ![self.backgroundContext save:&error])
            [subject sendError:error];
        else {
            [subject sendNext:obj];
            [subject sendCompleted];
        }
    }];
    return subject;

}
@end
