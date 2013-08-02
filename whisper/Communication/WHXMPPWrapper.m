//
//  WHXMPPWrapper.m
//  whisper
//
//  Created by Thomas Goyne on 7/16/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHXMPPWrapper.h"

#import "WHXMPPRoster.h"
#import "WHError.h"

#import "XMPP.h"
#import "XMPPReconnect.h"

@implementation WHChatMessage
- (WHChatMessage *)initWithSenderJid:(NSString *)senderJid body:(NSString *)body {
    self = [super init];
    if (self) {
        self.senderJid = senderJid;
        self.body = body;
    }
    return self;
}
@end

@interface WHXMPPWrapper ()
@property (nonatomic, strong) RACSubject *messages;
@property (nonatomic, strong) RACSubject *connectSignal;

@property (nonatomic, strong) XMPPStream *stream;
@property (nonatomic, strong) NSString *password;

@property (nonatomic, strong) XMPPReconnect *reconnect;
@property (nonatomic, strong) WHXMPPRoster *roster;
@end

@implementation WHXMPPWrapper
- (instancetype)init {
    if (self = [super init]) {
        self.messages = [RACReplaySubject subject];
        self.connectSignal = [RACReplaySubject subject];
        self.stream = [XMPPStream new];
        self.roster = [[WHXMPPRoster alloc] initWithXmppStream:self.stream];
    }
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
    self.stream.enableBackgroundingOnSocket = YES;

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
    return nil;
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
    [self.stream sendElement:[XMPPPresence presence]];
    [self.connectSignal sendCompleted];
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
        [self.messages sendNext:[[WHChatMessage alloc]
                                 initWithSenderJid:[message fromStr]
                                 body:[[message elementForName:@"body"] stringValue]]];
    }
}

- (void)xmppStreamDidRegister:(XMPPStream *)sender {
    [self.stream sendElement:[XMPPPresence presence]];
    [self.connectSignal sendCompleted];
}

- (void)xmppStream:(XMPPStream *)sender didNotRegister:(NSXMLElement *)error {
    [self.connectSignal sendError:[WHError errorWithDescription:[error description]]];
}

@end
