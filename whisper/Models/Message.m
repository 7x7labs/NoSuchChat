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

#import <CommonCrypto/CommonDigest.h>

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

- (NSURL *)avatarURL:(NSString *)currentUserJid {

    // TODO: Better way to lookup the jid?
    NSString *jid = ([self.incoming boolValue] ? self.contact.jid : currentUserJid);
    NSURL *avatarURL = [self buildGravatarURL:jid];
    
    return avatarURL;
}

// TODO: Move this method to an appropriate home
- (NSURL *)buildGravatarURL:(NSString *)emailAddress {
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
@end
