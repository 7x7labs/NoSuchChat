//
//  WHXMPPWrapper.m
//  whisper
//
//  Created by Thomas Goyne on 7/16/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHXMPPWrapper.h"

#import "WHAppDelegate.h"
#import "WHCrypto.h"
#import "WHError.h"
#import "WHKeyPair.h"
#import "WHXMPPCapabilities.h"
#import "WHXMPPRoster.h"

#import <EXTScope.h>
#import <Reachability/Reachability.h>
#import <XMPPFramework/NSData+XMPP.h>
#import <XMPPFramework/NSXMLElement+XEP_0203.h>
#import <XMPPFramework/XMPP.h>
#import <XMPPFramework/XMPPReconnect.h>

@implementation WHChatMessage
- (WHChatMessage *)initWithSenderJid:(NSString *)senderJid body:(NSString *)body sent:(NSDate *)sent {
    self = [super init];
    if (self) {
        self.senderJid = [[XMPPJID jidWithString:senderJid] bare];
        self.body = body;
        self.sent = sent ?: [NSDate date];
    }
    return self;
}
@end

@interface WHXMPPWrapper ()
@property (nonatomic, strong) RACSubject *messages;
@property (nonatomic, strong) RACSubject *connectSignal;
@property (nonatomic, strong) NSMutableDictionary *pendingMessages;

@property (nonatomic, strong) XMPPStream *stream;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) Reachability *reach;

@property (nonatomic, strong) XMPPReconnect *reconnect;
@property (nonatomic, strong) WHXMPPRoster *roster;
@property (nonatomic, strong) WHXMPPCapabilities *capabilities;
@property (nonatomic, strong) dispatch_source_t offlineMessagesTimer;
@end

@implementation WHXMPPWrapper
- (void)dealloc {
    [self.stream sendElement:[XMPPPresence presenceWithType:@"unavailable"]];
}

- (instancetype)init {
    if (!(self = [super init])) return self;
    self.messages = [RACReplaySubject subject];
    self.connectSignal = [RACReplaySubject subject];
    self.pendingMessages = [NSMutableDictionary dictionary];
    self.reach = [Reachability reachabilityWithHostname:kXmppServerHost];
    self.stream = [XMPPStream new];
    self.roster = [[WHXMPPRoster alloc] initWithXmppStream:self.stream];
    self.capabilities = [[WHXMPPCapabilities alloc] initWithStream:self.stream];

    @weakify(self)
    self.reach.reachableBlock = ^(Reachability *_) {
        @strongify(self)
        [self.reconnect manualStart];
    };

    return self;
}

- (RACSignal *)connectToServer:(NSString *)server
                          port:(uint16_t)port
                      username:(NSString *)username
                      password:(NSString *)password
{
    self.password = password;

    [self.stream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    self.stream.hostName = server;
    self.stream.hostPort = port;
    self.stream.myJID = [XMPPJID jidWithString:username];

    [self.reach startNotifier];

    // Should dump this off on a queue rather than running synchronously
    NSError *error = nil;
    if (![self.stream connectWithTimeout:XMPPStreamTimeoutNone error:&error]) {
        NSLog(@"Error connecting: %@", error);
        [self.connectSignal sendError:error];
    }

    [(self.reconnect = [XMPPReconnect new]) activate:self.stream];

    return self.connectSignal;
}

- (RACSignal *)sendMessage:(NSString *)body to:(NSString *)recipient {
    NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
    [message addAttributeWithName:@"type" stringValue:@"chat"];
    [message addAttributeWithName:@"to" stringValue:recipient];
    [message addChild:[NSXMLElement elementWithName:@"body" stringValue:body]];
    [self.stream sendElement:message];
    return self.pendingMessages[body] = [RACReplaySubject subject];
}

- (void)setDisplayName:(NSString *)displayName {
    _displayName = displayName;

    NSString *tmpl =
    @"<iq type='set'>"
    @"   <pubsub xmlns='http://jabber.org/protocol/pubsub'>"
    @"       <publish node='http://jabber.org/protocol/nick'>"
    @"           <item><nick xmlns='http://jabber.org/protocol/nick'>%@</nick></item>"
    @"       </publish>"
    @"   </pubsub>"
    @"</iq>";

    NSString *encrypted = [[WHCrypto encrypt:displayName key:[WHKeyPair getOwnGlobalKeyPair]] xmpp_base64Encoded];
    NSError *error;
    NSXMLElement *iq = [[NSXMLElement alloc] initWithXMLString:[NSString stringWithFormat:tmpl, encrypted]
                                                         error:&error];
    NSAssert(iq && !error, @"Error encoding nickname iq: %@", error);
    [self.stream sendElement:iq];
}

- (void)resetOfflineMessagesTimer {
    if (self.offlineMessagesTimer)
        dispatch_source_set_timer(self.offlineMessagesTimer,
                                  dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 1),
                                  1 * NSEC_PER_SEC,
                                  0);
}

#pragma mark - xmppStream
- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings {
    settings[(NSString *)kCFStreamSSLAllowsAnyRoot] = @YES;
    settings[(NSString *)kCFStreamSSLPeerName] = [NSNull null];
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender {
    NSError *error = nil;
    if (![self.stream authenticateWithPassword:self.password error:&error]) {
        NSLog(@"Error authenticating: %@", error);
        [self.connectSignal sendError:error];
    }
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:error {
    [self.connectSignal sendError:error];
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender {
    // Notify the app delegate once a second has passed with no messages
    // received, since there's no notification of when offline message playback
    // is complete.
    self.offlineMessagesTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    [self resetOfflineMessagesTimer];
    dispatch_source_set_event_handler(self.offlineMessagesTimer, ^{
        dispatch_source_cancel(self.offlineMessagesTimer);
        self.offlineMessagesTimer = nil;
        [(WHAppDelegate *)[[UIApplication sharedApplication] delegate] backgroundFetchComplete];
    });
    dispatch_resume(self.offlineMessagesTimer);

    [self.stream sendElement:[XMPPPresence presence]];
    [self.connectSignal sendCompleted];

    // Reconnect module now handles monitoring the connection
    [self.reach stopNotifier];
    self.reach = nil;
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)_ {
    // Either something has gone bizzarely wrong or we haven't registered yet
    NSError *error = nil;
    if (![self.stream registerWithPassword:self.password error:&error]) {
        NSLog(@"Error registering: %@", error);
        [self.connectSignal sendError:error];
    }
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {
    [self resetOfflineMessagesTimer];

    if ([message isChatMessageWithBody]) {
        [(RACSubject *)self.messages sendNext:[[WHChatMessage alloc]
                                               initWithSenderJid:[message fromStr]
                                               body:[[message elementForName:@"body"] stringValue]
                                               sent:[message delayedDeliveryDate]]];
    }
}

- (void)xmppStreamDidRegister:(XMPPStream *)sender {
    [self xmppStreamDidConnect:sender];
}

- (void)xmppStream:(XMPPStream *)sender didNotRegister:(NSXMLElement *)error {
    [self.connectSignal sendError:[WHError errorWithDescription:[error description]]];
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)message {
    NSString *body = [message body];
    [self.pendingMessages[body] sendCompleted];
    [self.pendingMessages removeObjectForKey:body];
}

- (void)xmppStream:(XMPPStream *)sender didFailToSendMessage:(XMPPMessage *)message error:(NSError *)error {
    NSString *body = [message body];
    [self.pendingMessages[body] sendError:error];
    [self.pendingMessages removeObjectForKey:body];
}

@end
