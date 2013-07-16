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

@implementation Contact
+ (NSArray *)all {
    NSError *error;
    NSArray *array = [[WHCoreData managedObjectContext]
                      executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"Contact"]
                      error:&error];
    if (!array)
        NSLog(@"Error fetching contacts: %@", error);
    return array;
}

+ (Contact *)createWithName:(NSString *)name {
    Contact *contact = [NSEntityDescription insertNewObjectForEntityForName:@"Contact" inManagedObjectContext:[WHCoreData managedObjectContext]];
    contact.name = name;

    NSError *error;
    if (![[WHCoreData managedObjectContext] save:&error])
        NSLog(@"Error saving contact: %@", error);

    return contact;
}

- (void)addSentMessage:(NSString *)text date:(NSDate *)date {
    Message *message = [NSEntityDescription insertNewObjectForEntityForName:@"Message" inManagedObjectContext:[WHCoreData managedObjectContext]];
    message.text = text;
    message.sent = date;
    message.incoming = @NO;
    message.contact = self;

    NSError *error;
    if (![[WHCoreData managedObjectContext] save:&error])
        NSLog(@"Error saving message: %@", error);
}

- (void)addReceivedMessage:(NSString *)text date:(NSDate *)date {
    Message *message = [NSEntityDescription insertNewObjectForEntityForName:@"Message" inManagedObjectContext:[WHCoreData managedObjectContext]];
    message.text = text;
    message.sent = date;
    message.incoming = @YES;
    message.contact = self;

    NSError *error;
    if (![[WHCoreData managedObjectContext] save:&error])
        NSLog(@"Error saving message: %@", error);
}

- (NSArray *)orderedMessages {
    return [self.messages sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"sent" ascending:NO]]];
}

@end
