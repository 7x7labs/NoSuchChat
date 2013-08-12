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
#import "WHCrypto.h"
#import "WHKeyPair.h"

#import "NSData+XMPP.h"

NSString * const WHContactAddedNotification = @"WHContactAddedNotification";

static NSManagedObjectContext *moc() {
    return [WHCoreData managedObjectContext];
}

@interface Contact () {
    WHKeyPair *_ownKey;
    WHKeyPair *_contactKey;
    WHKeyPair *_globalKey;
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

+ (RACSignal *)createWithName:(NSString *)name jid:(NSString *)jid {
    RACSubject *subject = [RACReplaySubject subject];
    NSManagedObjectContext *moc = [WHCoreData backgroundManagedObjectContext];
    [moc performBlock:^{
        __block Contact *contact = [self contactForJid:jid managedObjectContext:moc];
        if (contact) {
            [subject sendNext:contact];
            [subject sendCompleted];
        }

        [[WHCoreData insertObjectOfType:@"Contact" withBlock:^(NSManagedObject *obj) {
            contact = (Contact *)obj;
            contact.name = name;
            contact.jid = jid;
        }] subscribeError:^(NSError *error) {
            [subject sendError:error];
        } completed:^{
            [[NSNotificationCenter defaultCenter] postNotificationName:WHContactAddedNotification
                                                                object:nil
                                                              userInfo:@{@"created": contact}];
            [subject sendNext:contact];
            [subject sendCompleted];
        }];
    }];
    return subject;
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

- (RACSignal *)addMessage:(NSString *)text date:(NSDate *)date incoming:(NSNumber *)incoming {
    NSManagedObjectID *ownID = self.objectID;
    RACSignal *signal = [WHCoreData insertObjectOfType:@"Message" withBlock:^(NSManagedObject *obj) {
        Message *message = (Message *)obj;
        message.text = text;
        message.sent = date;
        message.incoming = incoming;
        message.contact = (Contact *)[[WHCoreData backgroundManagedObjectContext]
                                      objectWithID:ownID];
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

- (WHKeyPair *)globalKey {
    if (!_globalKey)
        _globalKey = [WHKeyPair getGlobalKeyFromJid:self.jid];
    return _globalKey;
}

- (NSString *)encrypt:(NSString *)message {
    return [[WHCrypto encrypt:message
                 senderKey:self.ownKey
               receiverKey:self.contactKey] xmpp_base64Encoded];
}

- (NSString *)decrypt:(NSString *)message {
    return [WHCrypto decrypt:[[message dataUsingEncoding:NSUTF8StringEncoding] xmpp_base64Decoded]
                senderKey:self.contactKey
              receiverKey:self.ownKey];
}

- (NSString *)decryptGlobal:(NSString *)message {
    return [WHCrypto decrypt:[[message dataUsingEncoding:NSUTF8StringEncoding] xmpp_base64Decoded]
                      key:self.globalKey];
}

@end
