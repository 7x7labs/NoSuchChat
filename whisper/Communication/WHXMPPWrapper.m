//
//  WHXMPPWrapper.m
//  whisper
//
//  Created by Thomas Goyne on 7/16/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHXMPPWrapper.h"

#import <ReactiveCocoa/ReactiveCocoa.h>
#import "XMPP.h"

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
@end

@implementation WHXMPPWrapper
- (RACSignal *)connectToServer:(NSString *)server
                          port:(uint16_t)port
                      username:(NSString *)username
                      password:(NSString *)password
{
    self.messages = [RACReplaySubject replaySubjectWithCapacity:RACReplaySubjectUnlimitedCapacity];
    self.connectSignal = [RACReplaySubject replaySubjectWithCapacity:RACReplaySubjectUnlimitedCapacity];

    self.stream = [XMPPStream new];
    [self.stream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    self.stream.hostName = server;
    self.stream.hostPort = port;
    self.stream.myJID = [XMPPJID jidWithString:username];

    // Should dump this off on a queue rather than running synchronously
	NSError *error = nil;
	if (![self.stream connectWithTimeout:XMPPStreamTimeoutNone error:&error]) {
		NSLog(@"Error connecting: %@", error);
        [self.connectSignal sendError:error];
	}

    return self.connectSignal;
}

- (void)sendMessage:(NSString *)body to:(NSString *)recipient {
    NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
    [message addAttributeWithName:@"type" stringValue:@"chat"];
    [message addAttributeWithName:@"to" stringValue:recipient];
    [message addChild:[NSXMLElement elementWithName:@"body" stringValue:body]];

    [self.stream sendElement:message];
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
    [self.connectSignal sendError:[NSError errorWithDomain:@"WHXMPPWrapper" code:0 userInfo:@{}]];
}
@end
