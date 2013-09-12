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
#import "WHXMPPRoster.h"
#import "WHXMPPWrapper.h"

#import <EXTScope.h>
#import <ReactiveCocoa/NSNotificationCenter+RACSupport.h>

@interface WHChatClient ()
@property (nonatomic, strong) WHXMPPWrapper *xmpp;
@property (nonatomic, strong) NSArray *contacts;
@property (nonatomic, strong) NSString *jid;
@property (nonatomic) BOOL connected;
@property (nonatomic, strong) RACSubject *cancelSignal;
@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) RACSignal *incomingMessages;
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

    self.displayName = [[NSUserDefaults standardUserDefaults] stringForKey:@"displayName"];
    [NSUserDefaults.standardUserDefaults.rac_lift setObject:RACAble(self, displayName)
                                                     forKey:@"displayName"];
    RACBind(self.xmpp, displayName) = RACBind(self, displayName);
    RACBind(self, connected) = RACBind(self.xmpp, connected);

    @weakify(self)
    self.cancelSignal = [RACSubject subject];
    RAC(self, contacts) = [[[[[RACSignal
        merge:@[[NSNotificationCenter.defaultCenter
                 rac_addObserverForName:WHContactAddedNotification object:nil],
                [NSNotificationCenter.defaultCenter
                 rac_addObserverForName:WHContactRemovedNotification object:nil]]]
        takeUntil:self.cancelSignal]
        deliverOn:[RACScheduler mainThreadScheduler]]
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
                  localNotification.userInfo = @{@"jid": contact.jid};
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
         [WHAlert alertWithError:error];
    }];

    [self.xmpp.roster setShow:@""];
    return self;
}

- (RACSignal *)sendMessage:(NSString *)body to:(Contact *)contact {
    RACSignal *saveSignal = [contact addSentMessage:body date:[NSDate date]];
    RACSignal *sendSignal = [self.xmpp sendMessage:[contact encrypt:body] to:contact.jid];
    return [RACSignal merge:@[saveSignal, sendSignal]];
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

- (void)disconnect {
    [self.cancelSignal sendCompleted];
    self.xmpp = nil;
}
@end
