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
#import "WHXMPPRoster.h"
#import "WHXMPPWrapper.h"

#import <EXTScope.h>
#import <ReactiveCocoa/NSNotificationCenter+RACSupport.h>

@interface WHChatClient ()
@property (nonatomic, strong) NSObject<WHXMPPStream> *xmpp;
@property (nonatomic, strong) NSArray *contacts;
@property (nonatomic, strong) NSString *jid;
@property (nonatomic, strong) RACSubject *cancelSignal;
@property (nonatomic, strong) RACSignal *incomingMessages;
@end

@implementation WHChatClient
+ (WHChatClient *)clientForServer:(NSString *)host port:(uint16_t)port {
    return [[self alloc] initForServer:host port:port stream:[WHXMPPWrapper new]];
}

+ (WHChatClient *)clientForServer:(NSString *)host
                             port:(uint16_t)port
                           stream:(id<WHXMPPStream>)xmpp
{
    return [[self alloc] initForServer:host port:port stream:xmpp];
}

- (WHChatClient *)initForServer:(NSString *)host
                           port:(uint16_t)port
                         stream:(id<WHXMPPStream>)xmpp
{
    self = [super init];
    if (!self) return self;

    WHAccount *account = [WHAccount get];
    self.jid = account.jid;
    self.xmpp = xmpp;

    self.displayName = [[NSUserDefaults standardUserDefaults] stringForKey:@"displayName"];
    if (!self.displayName)
        self.displayName = @"Display Name";
    [RACAble(self, displayName) subscribeNext:^(NSString *displayName) {
        [[NSUserDefaults standardUserDefaults] setObject:displayName forKey:@"displayName"];
    }];

    self.cancelSignal = [RACSubject subject];
    RAC(self, contacts) =
        [[[[NSNotificationCenter.defaultCenter
           rac_addObserverForName:WHContactAddedNotification object:nil]
          takeUntil:self.cancelSignal]
          map:^(NSNotification *_) { return [Contact all]; }]
          startWith:[Contact all]];

    @weakify(self)
    self.incomingMessages = [self.xmpp.messages flattenMap:^(id message) {
        @strongify(self)
        Contact *contact = [self.contacts.rac_sequence objectPassingTest:^(Contact *c) {
            return [c.jid isEqualToString:[message senderJid]];
        }];

        if (!contact)
            return [RACSignal return:nil];
        return [contact addReceivedMessage:[contact decrypt:[message body]]
                                      date:[NSDate date]];
    }];

    self.xmpp.roster.contactJids =
        [NSMutableSet setWithArray:[[self.contacts.rac_sequence
                                     map:^(Contact *c) { return c.jid; }]
                                     array]];

    RACSignal *connectSignal = [self.xmpp connectToServer:host
                                                     port:port
                                                 username:account.jid
                                                 password:account.password];
    [connectSignal subscribeError:^(NSError *error) {
        [[[UIAlertView alloc] initWithTitle:nil
                                    message:[error localizedDescription]
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }];

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
@end
