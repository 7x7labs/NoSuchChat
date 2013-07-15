//
//  Contact.m
//  whisper
//
//  Created by Thomas Goyne on 7/15/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "Contact.h"

#import "WHCoreData.h"

@implementation Contact
@dynamic name;

+ (NSArray *)all {
    NSManagedObjectContext *moc = [WHCoreData managedObjectContext];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Contact"];
    NSError *error;
    NSArray *array = [moc executeFetchRequest:request error:&error];
    if (!array)
        NSLog(@"Error fetching contacts: %@", error);
    return array;
}

+ (Contact *)createWithName:(NSString *)name {
    Contact *contact = [NSEntityDescription insertNewObjectForEntityForName:@"Contact" inManagedObjectContext:[WHCoreData managedObjectContext]];
    contact.name = name;
    return contact;
}
@end
