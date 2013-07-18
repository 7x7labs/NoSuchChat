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
#import "WHXMPPWrapper.h"

#import <EXTScope.h>
#import <ReactiveCocoa/NSNotificationCenter+RACSupport.h>

@interface WHChatClient ()
@property (nonatomic, strong) NSObject<WHXMPPStream> *xmpp;
@property (nonatomic, strong) NSArray *contacts;

- (WHChatClient *)initForServer:(NSString *)host port:(uint16_t)port;
@end

@implementation WHChatClient
+ (WHChatClient *)clientForServer:(NSString *)host port:(uint16_t)port {
    return [[self alloc] initForServer:host port:port];
}

- (WHChatClient *)initForServer:(NSString *)host port:(uint16_t)port {
    self = [super init];
    if (!self) return self;

    self.xmpp = [WHXMPPWrapper new];

    WHAccount *account = [WHAccount get];
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

    RAC(self, contacts) =
        [[[NSNotificationCenter.defaultCenter
           rac_addObserverForName:NSManagedObjectContextObjectsDidChangeNotification
           object:nil]
          map:^(NSNotification *_) { return [Contact all]; }]
         startWith:[Contact all]];

    @weakify(self)
    [self.xmpp.messages subscribeNext:^(id message) {
        @strongify(self)
        for (Contact *contact in self.contacts) {
            if ([contact.name isEqualToString:[message senderJid]]) {
                [contact addReceivedMessage:[message body] date:[NSDate date]];
                return;
            }
        }
    }];

    return self;
}

- (void)sendMessage:(NSString *)body to:(Contact *)contact {
    [contact addSentMessage:body date:[NSDate date]];
    [self.xmpp sendMessage:body to:contact.jid];
}
@end
