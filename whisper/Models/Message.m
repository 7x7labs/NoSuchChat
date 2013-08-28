//
//  Message.m
//  whisper
//
//  Created by Thomas Goyne on 7/16/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "Contact.h"
#import "Message.h"

#import "WHCoreData.h"

@interface Message ()
@end

@implementation Message
+ (RACSignal *)deleteOlderThan:(NSDate *)date {
    RACSubject *subject = [RACReplaySubject subject];

    NSManagedObjectContext *context = [WHCoreData backgroundManagedObjectContext];
    [context performBlock:^{
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Message"];
        request.predicate = [NSPredicate predicateWithFormat:@"sent < %@", date];
        NSError *error = nil;
        NSArray *all = [context executeFetchRequest:request error:&error];
        if (error)
            return [subject sendError:error];

        for (Message *message in all)
            [context deleteObject:message];

        if (![context save:&error])
            return [subject sendError:error];

        [[WHCoreData save] subscribeError:^(NSError *e) {
            [subject sendError:e];
        } completed:^{
            [subject sendCompleted];
        }];
    }];
    return subject;
}

- (RACSignal *)delete {
    return [WHCoreData deleteObject:self];
}
@end
