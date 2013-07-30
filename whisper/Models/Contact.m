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
#import "WHKeyPair.h"
#import "WHPGP.h"

#import "NSData+XMPP.h"
#import <ReactiveCocoa/ReactiveCocoa.h>

NSString * const WHContactAddedNotification = @"WHContactAddedNotification";

static NSManagedObjectContext *moc() {
    return [WHCoreData managedObjectContext];
}

@interface Contact () {
    WHKeyPair *_ownKey;
    WHKeyPair *_contactKey;
}
@end

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
    Contact *contact = [self contactForJid:jid managedObjectContext:moc()];
    if (contact)
        return contact;

    contact = [NSEntityDescription insertNewObjectForEntityForName:@"Contact"
                                            inManagedObjectContext:moc()];
    contact.name = name;
    contact.jid = jid;

    NSError *error;
    if (![moc() save:&error])
        NSLog(@"Error saving contact: %@", error);

    [[NSNotificationCenter defaultCenter] postNotificationName:WHContactAddedNotification
                                                        object:nil
                                                      userInfo:@{@"contact": contact}];

    return contact;
}

+ (Contact *)contactForJid:(NSString *)jid
      managedObjectContext:(NSManagedObjectContext *)context
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Contact"];
    request.predicate = [NSPredicate predicateWithFormat:@"jid = %@", jid];
    NSError *error = nil;
    Contact *contact = [[context executeFetchRequest:request error:&error] lastObject];
    if (error)
        NSLog(@"Error fetching contact with jid %@: %@", jid, error);
    return contact;
}

- (Contact *)bgSelf {
    return (Contact *)[[WHCoreData backgroundManagedObjectContext]
                       existingObjectWithID:self.objectID
                       error:nil];
}

- (RACSignal *)addMessage:(NSString *)text date:(NSDate *)date incoming:(NSNumber *)incoming {
    RACSignal *signal = [WHCoreData insertObjectOfType:@"Message" withBlock:^(NSManagedObject *obj) {
        Message *message = (Message *)obj;
        message.text = text;
        message.sent = date;
        message.incoming = incoming;
        message.contact = [self bgSelf];
    }];
    [signal subscribeError:^(NSError *error) {
        NSLog(@"Error saving message: %@", error);
     }];
    return signal;
}

- (RACSignal *)addSentMessage:(NSString *)text date:(NSDate *)date {
    return [self addMessage:text date:date incoming:@NO];
}

- (RACSignal *)addReceivedMessage:(NSString *)text date:(NSDate *)date {
    return [self addMessage:text date:date incoming:@YES];
}

- (WHKeyPair *)ownKey {
    if (!_ownKey)
        _ownKey = [WHKeyPair getOwnKeyPairForJid:self.jid];
    return _ownKey;
}

- (WHKeyPair *)contactKey {
    if (!_contactKey)
        _contactKey = [WHKeyPair getKeyFromJid:self.jid];
    return _contactKey;
}

- (NSString *)encrypt:(NSString *)message {
    return [[WHPGP encrypt:message
                 senderKey:self.ownKey
               receiverKey:self.contactKey] xmpp_base64Encoded];
}

- (NSString *)decrypt:(NSString *)message {
    return [WHPGP decrypt:[[message dataUsingEncoding:NSUTF8StringEncoding] xmpp_base64Decoded]
                senderKey:self.contactKey
              receiverKey:self.ownKey];
}

@end
