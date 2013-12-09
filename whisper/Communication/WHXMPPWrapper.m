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
@property (nonatomic) BOOL connected;
@property (nonatomic, strong) NSMutableDictionary *pendingMessages;

@property (nonatomic, strong) XMPPStream *stream;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) Reachability *reach;

@property (nonatomic, strong) XMPPReconnect *reconnect;
@property (nonatomic, strong) WHXMPPRoster *roster;
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
    [self.stream sendElement:[XMPPPresence presence]];
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
    self.connected = NO;
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender {
    [self.stream sendElement:[XMPPPresence presence]];
    [self.connectSignal sendCompleted];
    self.connected = YES;

    // Reconnect module now handles monitoring the connection
    [self.reach stopNotifier];
    self.reach = nil;

    @weakify(self)
    [[RACAbleWithStart(((WHAppDelegate *)[[UIApplication sharedApplication] delegate]), deviceToken)
     filter:^BOOL (NSData *deviceToken) { return !!deviceToken; }]
     subscribeNext:^(NSData *deviceToken) {
         @strongify(self)
         NSXMLElement *element = [NSXMLElement elementWithName:@"deviceToken" xmlns:@"7x7:apns"];
         element.stringValue = [deviceToken xmpp_hexStringValue];
         [self.stream sendElement:[XMPPIQ iqWithType:@"set" child:element]];
     }];
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

- (XMPPPresence *)xmppStream:(XMPPStream *)sender willSendPresence:(XMPPPresence *)presence {
    if (![[presence type] isEqualToString:@"available"]) return presence;

    // XEP-0172 explicitly says not to do this. Oh well.
    NSXMLElement *nick = [NSXMLElement elementWithName:@"nick" xmlns:@"http://jabber.org/protocol/nick"];
    nick.stringValue = [[WHCrypto encrypt:self.displayName key:[WHKeyPair getOwnGlobalKeyPair]] xmpp_base64Encoded];
    [presence addChild:nick];

	return presence;
}
@end
