//
//  Contact.h
//  whisper
//
//  Created by Thomas Goyne on 7/15/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "_Contact.h"

@class RACSignal;
@class WHKeyPair;

extern NSString * const WHContactAddedNotification;

@interface Contact : _Contact
+ (NSArray *)all;
+ (Contact *)createWithName:(NSString *)name jid:(NSString *)jid;
+ (Contact *)contactForJid:(NSString *)jid
      managedObjectContext:(NSManagedObjectContext *)context;

- (RACSignal *)addSentMessage:(NSString *)text date:(NSDate *)date;
- (RACSignal *)addReceivedMessage:(NSString *)text date:(NSDate *)date;

- (NSString *)encrypt:(NSString *)message;
- (NSString *)decrypt:(NSString *)message;

@property (nonatomic, readonly) WHKeyPair *ownKey;
@property (nonatomic, readonly) WHKeyPair *contactKey;
@end
