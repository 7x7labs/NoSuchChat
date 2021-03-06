//
//  WHXMPPRoster.m
//  whisper
//
//  Created by Thomas Goyne on 7/26/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHXMPPRoster.h"

#import "Contact.h"
#import "WHAccount.h"
#import "WHCoreData.h"
#import "WHCrypto.h"

#import "XMPP.h"
#import "NSData+XMPP.h"

@interface WHXMPPRoster ()
@property (nonatomic, strong) XMPPStream *stream;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSManagedObjectContext *objectContext;
@property (nonatomic, strong) NSString *show;
@property (nonatomic, strong) NSMutableSet *subscriptionsRequested;
@end

@implementation WHXMPPRoster
- (instancetype)initWithXmppStream:(XMPPStream *)stream {
    if (!(self = [super init])) return self;

    self.stream = stream;
    self.queue = dispatch_queue_create("WHXMPPRoster", 0);

    dispatch_async(self.queue, ^{
        self.objectContext = [NSManagedObjectContext new];
        self.objectContext.parentContext = [WHCoreData managedObjectContext];

        NSError *error;
        NSArray *contacts = [self.objectContext
                             executeFetchRequest:[NSFetchRequest fetchRequestWithEntityName:@"Contact"]
                             error:&error];
        if (error)
            return NSLog(@"Error fetching contacts for offline setting: %@", error);

        for (Contact *contact in contacts)
            contact.onlineValue = NO;

        [self.objectContext save:&error];
        if (error)
            return NSLog(@"Error saving contacts after setting offline: %@", error);

        [[WHCoreData save] subscribeError:^(NSError *err) {
            NSLog(@"Error propagating saving after setting offline: %@", error);
        }];
    });

    [stream addDelegate:self delegateQueue:self.queue];
    self.subscriptionsRequested = [NSMutableSet set];

    return self;
}

- (void)dealloc {
    [self.stream removeDelegate:self];
}

- (void)addContact:(Contact *)contact {
    @synchronized(self.contactJids) {
        [self.contactJids addObject:contact.jid];
    }

    // Add the contact to the roster
    [self sendRosterIQ:@"set" body:@{@"jid": contact.jid}];

    // Ask to subscribe to the contact and approve any pending subscription from the contact
    XMPPJID *jid = [XMPPJID jidWithString:contact.jid];
    [self sendPresenceType:@"subscribe" to:jid];
    [self sendPresenceType:@"subscribed" to:jid];
}

- (void)removeContact:(NSString *)contactJid {
    @synchronized(self.contactJids) {
        [self.contactJids removeObject:contactJid];
    }

    // Remove the contact from the roster, which also removes subscriptions in
    // both directions
    [self sendRosterIQ:@"set" body:@{@"jid": contactJid,
                                     @"subscription": @"remove"}];
}

- (void)setShow:(NSString *)show {
    _show = show;
    [self sendStatus];
}

- (void)sendRosterIQ:(NSString *)type body:(NSDictionary *)body {
    NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:roster"];
    if (body) {
        NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
        for (NSString *key in body)
            [item addAttributeWithName:key stringValue:body[key]];
        [query addChild:item];
    }
    [self.stream sendElement:[XMPPIQ iqWithType:type child:query]];
}

- (void)sendPresenceType:(NSString *)type to:(XMPPJID *)jid {
    [self.stream sendElement:[XMPPPresence presenceWithType:type to:[jid bareJID]]];
}

- (void)sendStatus {
    XMPPPresence *presence = [XMPPPresence presence];
    [presence addChild:[NSXMLElement elementWithName:@"show" stringValue:self.show]];
    [self.stream sendElement:presence];
}

- (void)unsubscribe:(NSString *)jid {
    Contact *c = [Contact contactForJid:jid managedObjectContext:self.objectContext];
    @try {
        [c delete];
        [self removeContact:jid];
    }
    @catch (NSException *exception) {
        // Invalid contact that's already been deleted elsewhere
        // No need to do anything
    }
}

#pragma mark - XMPPStreamDelegate
- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender {
    // Request the roster from the server
    // Required to get the presence updates we've subscribed to
    [self sendRosterIQ:@"get" body:nil];
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
    NSXMLElement *query = [iq elementForName:@"query" xmlns:@"jabber:iq:roster"];
    if (!query) return NO;

    // Get the set of jids we're already subscribed to
    NSMutableSet *jids = [NSMutableSet set];
    for (NSXMLElement *item in [query elementsForName:@"item"]) {
        NSString *status = [item attributeStringValueForName:@"subscription"];
        if ([status isEqualToString:@"both"] ||
            [status isEqualToString:@"to"] ||
            [[item attributeStringValueForName:@"ask"] isEqualToString:@"subscribe"])
        {
            XMPPJID *jid = [XMPPJID jidWithString:[item attributeStringValueForName:@"jid"]];
            [jids addObject:[jid bare]];
        }
    }

    [self.stream sendElement:[XMPPIQ iqWithType:@"result" elementID:[iq elementID]]];

    // Subscribe to any contacts we aren't already subscribed to
    @synchronized(self.contactJids) {
        for (NSString *jid in self.contactJids) {
            if ([jids containsObject:jid] || [self.subscriptionsRequested containsObject:jid]) continue;
            [self.subscriptionsRequested addObject:jid];
            [self sendPresenceType:@"subscribe" to:[XMPPJID jidWithString:jid]];
        }
    }

    return YES;
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence {
    // Subscription request (sender trying to subscribe to us)
    if ([[presence type] isEqualToString:@"subscribe"]) {
        if ([self.contactJids containsObject:[[presence from] bare]])
            [self sendPresenceType:@"subscribed" to:[presence from]];
        return;
    }

    // Subscription confirmation (us subscribing to sender)
    if ([[presence type] isEqualToString:@"subscribed"]) {
        // Acknowledge the subscription so that the server does not keep
        // notifying us about it
        [self sendPresenceType:@"subscribe" to:[presence from]];
        return;
    }

    // Contact refused our subscription request
    if ([[presence type] isEqualToString:@"unsubscribed"]) {
        [self unsubscribe:[[presence from] bare]];

        // Acknowledge the unsubscription so that the server does not keep
        // notifying us about it
        [self sendPresenceType:@"unsubscribe" to:[presence from]];
        return;
    }

    // Contact has removed us, so remove them
    if ([[presence type] isEqualToString:@"unsubscribe"]) {
        [self unsubscribe:[[presence from] bare]];
        return;
    }

    if ([[presence type] isEqualToString:@"probe"]) {
        // Server wants our status
        [self sendStatus];
        return;
    }

    BOOL online = YES;
    if ([[presence type] isEqualToString:@"unavailable"])
        online = NO;
    else if (![[presence type] isEqualToString:@"available"])
        return;

    XMPPJID *jid = [presence from];
    Contact *c = [Contact contactForJid:[jid bare] managedObjectContext:self.objectContext];
    if (!c) return;

    [WHCoreData modifyObject:c withBlock:^(NSManagedObject *obj) {
        Contact *contact = (Contact *)obj;
        contact.onlineValue = online;
        NSArray *nick = [presence nodesForXPath:@"//*[namespace-uri()='http://jabber.org/protocol/nick' and local-name()='nick']" error:nil];
        if ([nick count])
            contact.name = [contact decryptGlobal:[nick[0] stringValue]];
    }];
}

@end
