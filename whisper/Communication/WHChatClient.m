//
//  WHChatClient.m
//  whisper
//
//  Created by Thomas Goyne on 7/17/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHChatClient.h"

#import "Contact.h"
#import "WHAccount.h"
#import "WHAlert.h"
#import "WHKeyExchangePeer.h"
#import "WHMultipeerAdvertiser.h"
#import "WHXMPPRoster.h"
#import "WHXMPPWrapper.h"

#import <EXTScope.h>
#import <ReactiveCocoa/NSNotificationCenter+RACSupport.h>

@interface WHChatClient ()
@property (nonatomic, strong) WHXMPPWrapper *xmpp;
@property (nonatomic, strong) NSArray *contacts;
@property (nonatomic, strong) NSString *jid;
@property (nonatomic, strong) RACSubject *cancelSignal;
@property (nonatomic, strong) RACSignal *incomingMessages;
@property (nonatomic, strong) WHMultipeerAdvertiser *advertiser;
@end

@implementation WHChatClient
+ (WHChatClient *)clientForServer:(NSString *)host port:(uint16_t)port {
    return [[self alloc] initForServer:host port:port stream:[WHXMPPWrapper new]];
}

+ (WHChatClient *)clientForServer:(NSString *)host
                             port:(uint16_t)port
                           stream:(WHXMPPWrapper *)xmpp
{
    return [[self alloc] initForServer:host port:port stream:xmpp];
}

- (WHChatClient *)initForServer:(NSString *)host
                           port:(uint16_t)port
                         stream:(WHXMPPWrapper *)xmpp
{
    if (!(self = [super init])) return self;

    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"displayName": @"User Name"}];

    WHAccount *account = [WHAccount get];
    self.jid = account.jid;
    self.xmpp = xmpp;
    self.advertiser = [[WHMultipeerAdvertiser alloc] initWithJid:self.jid];

    self.displayName = [[NSUserDefaults standardUserDefaults] stringForKey:@"displayName"];
    [NSUserDefaults.standardUserDefaults.rac_lift setObject:RACAble(self, displayName)
                                                     forKey:@"displayName"];
    RACBind(self.advertiser.displayName) = RACBind(self.displayName);
    RACBind(self.xmpp.displayName) = RACBind(self.displayName);

    @weakify(self)
    [[[self.advertiser.invitations
       flattenMap:^(WHKeyExchangePeer *peer) {
           NSString *message = [NSString stringWithFormat:@"Connect to user \"%@\"?", peer.name];
           return [RACSignal zip:@[[RACSignal return:peer],
                                   [WHAlert alertWithMessage:message
                                                     buttons:@[@"Yes", @"No"]]]];
       }]
       flattenMap:^(RACTuple *result) {
           RACTupleUnpack(WHKeyExchangePeer *peer, NSNumber *button) = result;
           if ([button integerValue]) {
               [peer reject];
               return [RACSignal empty];
           }
           else {
               @strongify(self)
               return [peer connectWithJid:self.jid];
           }
       }]
       subscribeError:^(NSError *error) {
           [WHAlert alertWithMessage:[error localizedDescription]];
       }];

    self.cancelSignal = [RACSubject subject];
    RAC(self, contacts) =
        [[[[RACSignal merge:@[[NSNotificationCenter.defaultCenter
                               rac_addObserverForName:WHContactAddedNotification object:nil],
                              [NSNotificationCenter.defaultCenter
                               rac_addObserverForName:WHContactRemovedNotification object:nil]]]
         takeUntil:self.cancelSignal]
         map:^(NSNotification *notification) {
             @strongify(self)
             if (notification.userInfo[@"created"])
                 [self.xmpp.roster addContact:notification.userInfo[@"created"]];
             if (notification.userInfo[@"removed"])
                 [self.xmpp.roster removeContact:notification.userInfo[@"removed"]];
             return [Contact all];
         }]
         startWith:[Contact all]];

    RACMulticastConnection *incomingMessages =
        [[self.xmpp.messages
          flattenMap:^(id message) {
              @strongify(self)
              Contact *contact = [self.contacts.rac_sequence objectPassingTest:^(Contact *c) {
                  return [c.jid isEqualToString:[message senderJid]];
              }];

              if (!contact)
                  return [RACSignal return:nil];

              if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
                  UILocalNotification *localNotification = [UILocalNotification new];
                  localNotification.alertBody = [NSString stringWithFormat:@"New message from %@", contact.name];;
                  [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
              }

              return [contact addReceivedMessage:[contact decrypt:[message body]]
                                            date:[message sent]];
          }]
         multicast:[RACSubject subject]];
    [incomingMessages connect];
    self.incomingMessages = incomingMessages.signal;

    self.xmpp.roster.contactJids =
        [NSMutableSet setWithArray:[[self.contacts.rac_sequence
                                     map:^(Contact *c) { return c.jid; }]
                                     array]];

    RACSignal *connectSignal = [self.xmpp connectToServer:host
                                                     port:port
                                                 username:account.jid
                                                 password:account.password];
    [connectSignal subscribeError:^(NSError *error) {
         [WHAlert alertWithMessage:[error localizedDescription]];
    }];

    [self.xmpp.roster setShow:@""];
    return self;
}

- (RACSignal *)sendMessage:(NSString *)body to:(Contact *)contact {
    RACSignal *saveSignal = [contact addSentMessage:body date:[NSDate date]];
    [self.xmpp sendMessage:[contact encrypt:body] to:contact.jid];
    return saveSignal;
}

- (void)dealloc {
    [self.cancelSignal sendCompleted];
}

- (void)setStatus:(NSString *)status {
    [self.xmpp.roster setShow:status];
}

- (NSString *)availability {
    return self.xmpp.roster.show;
}

- (MCPeerID *)peerID {
    return self.advertiser.peerID;
}
@end
