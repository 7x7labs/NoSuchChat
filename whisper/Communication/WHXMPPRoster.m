//
//  WHXMPPRoster.m
//  whisper
//
//  Created by Thomas Goyne on 7/26/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHXMPPRoster.h"

#import "Contact.h"
#import "WHCoreData.h"

#import "XMPP.h"

@interface WHXMPPRoster ()
@property (nonatomic, strong) XMPPStream *stream;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSManagedObjectContext *objectContext;
@property (nonatomic, strong) NSString *show;
@property (nonatomic, strong) NSString *status;
@end

@implementation WHXMPPRoster
- (instancetype)initWithXmppStream:(XMPPStream *)stream {
    if (self = [super init]) {
        self.stream = stream;
        self.queue = dispatch_queue_create("WHXMPPRoster", 0);
        [stream addDelegate:self delegateQueue:self.queue];
        self.objectContext = [NSManagedObjectContext new];
        self.objectContext.parentContext = [WHCoreData managedObjectContext];
    }
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

- (void)removeContact:(Contact *)contact {
    @synchronized(self.contactJids) {
        [self.contactJids removeObject:contact.jid];
    }

    // Remove the contact from the roster, which also removes subscriptions in
    // both directions
    [self sendRosterIQ:@"set" body:@{@"jid": contact.jid,
                                     @"subscription": @"remove"}];
}

- (void)setShow:(NSString *)show status:(NSString *)status {
    self.show = show;
    self.status = status;
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
    [presence addChild:[NSXMLElement elementWithName:@"status" stringValue:self.status]];
    [self.stream sendElement:presence];
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
        for (NSString *contactJid in self.contactJids) {
            if ([jids containsObject:contactJid]) continue;
            [self sendPresenceType:@"subscribe" to:[XMPPJID jidWithString:contactJid]];
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

    // Contact refused our subscription request or removed us
    if ([[presence type] isEqualToString:@"unsubscribed"]) {
        // Remove the contact?

        // Acknowledge the unsubscription so that the server does not keep
        // notifying us about it
        [self sendPresenceType:@"unsubscribe" to:[presence from]];
        return;
    }

    if ([[presence type] isEqualToString:@"probe"]) {
        // Server wants our status
        [self sendStatus];
        return;
    }

    if ([[presence type] isEqualToString:@"unavailable"])
        return;

    XMPPJID *jid = [presence from];
    Contact *c = [Contact contactForJid:[jid bare] managedObjectContext:self.objectContext];
    if (!c) return;

    [WHCoreData modifyObject:c withBlock:^(NSManagedObject *obj) {
        Contact *contact = (Contact *)obj;
        contact.state = [presence show];
        contact.statusMessage = [presence status];
    }];
}

@end
