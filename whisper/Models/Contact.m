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

#import <CommonCrypto/CommonDigest.h>

NSString * const WHContactAddedNotification = @"WHContactAddedNotification";
NSString * const WHContactRemovedNotification = @"WHContactRemovedNotification";

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

- (RACSignal *)delete {
    NSString *jid = self.jid;
    return [[[WHCoreData deleteObject:self]
            doCompleted:^{
                [WHKeyPair deleteKeysForJid:jid];
                [[NSNotificationCenter defaultCenter] postNotificationName:WHContactRemovedNotification
                                                                    object:nil
                                                                  userInfo:@{@"removed": jid}];
            }] replay];
}

- (NSURL *)avatarURL {
    return [Contact avatarURLForEmail:self.jid];
}

// TODO: Move this method to an appropriate home
+ (NSURL *)avatarURLForEmail:(NSString *)emailAddress {
	NSString *curatedEmail = [[emailAddress stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
							  lowercaseString];
    
	const char *cStr = [curatedEmail UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, strlen(cStr), result);
    
	NSString *md5email = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                          result[0], result[1], result[2], result[3],
                          result[4], result[5], result[6], result[7],
                          result[8], result[9], result[10], result[11],
                          result[12], result[13], result[14], result[15]
                          ];
	NSString *gravatarEndPoint = [NSString stringWithFormat:@"http://www.gravatar.com/avatar/%@?s=80&d=identicon", md5email];
    
	return [NSURL URLWithString:gravatarEndPoint];
}

- (NSString *)friendlyStatus {
    NSString *status;
    status = [self.state length] == 0 ? @"online" : self.state;
    status = [status uppercaseString];
    return status;
}
@end
