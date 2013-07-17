//
//  Contact.m
//  whisper
//
//  Created by Thomas Goyne on 7/15/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "Contact.h"

#import "Message.h"
#import "WHCoreData.h"

static NSManagedObjectContext *moc() {
    return [WHCoreData managedObjectContext];
}

@implementation Contact
+ (NSArray *)all {
    NSError *error;
    NSArray *array = [moc()
                      executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"Contact"]
                      error:&error];
    if (!array)
        NSLog(@"Error fetching contacts: %@", error);
    return array;
}

+ (Contact *)createWithName:(NSString *)name jid:(NSString *)jid {
    Contact *contact = nil;
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Contact"];
    request.predicate = [NSPredicate predicateWithFormat:@"jid = %@", jid];
    NSError *error = nil;
    contact = [[moc() executeFetchRequest:request error:&error] lastObject];

    if (contact)
        return contact;
    if (error)
        NSLog(@"Error fetching contact with jid %@: %@", jid, error);

    contact = [NSEntityDescription insertNewObjectForEntityForName:@"Contact"
                                            inManagedObjectContext:moc()];
    contact.name = name;
    contact.jid = jid;

    if (![moc() save:&error])
        NSLog(@"Error saving contact: %@", error);

    return contact;
}

- (void)addSentMessage:(NSString *)text date:(NSDate *)date {
    Message *message = [NSEntityDescription insertNewObjectForEntityForName:@"Message"
                                                     inManagedObjectContext:moc()];
    message.text = text;
    message.sent = date;
    message.incoming = @NO;
    message.contact = self;

    NSError *error;
    if (![moc() save:&error])
        NSLog(@"Error saving message: %@", error);
}

- (void)addReceivedMessage:(NSString *)text date:(NSDate *)date {
    Message *message = [NSEntityDescription insertNewObjectForEntityForName:@"Message"
                                                     inManagedObjectContext:moc()];
    message.text = text;
    message.sent = date;
    message.incoming = @YES;
    message.contact = self;

    NSError *error;
    if (![moc() save:&error])
        NSLog(@"Error saving message: %@", error);
}

- (NSArray *)orderedMessages {
    return [self.messages sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"sent" ascending:NO]]];
}

@end
