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

@interface WHXMPPWrapper ()
@property (nonatomic, strong) RACSubject *messages;
@property (nonatomic, strong) RACSubject *connectSignal;

@property (nonatomic, strong) XMPPStream *stream;
@property (nonatomic, strong) NSString *password;
@property (nonatomic) BOOL createAccount;
@end

@implementation WHXMPPWrapper
- (RACSignal *)connectToServer:(NSString *)server
                          port:(uint16_t)port
                      username:(NSString *)username
                      password:(NSString *)password
{
    self.messages = [RACSubject subject];
    self.connectSignal = [RACSubject subject];

    self.stream = [XMPPStream new];
    [self.stream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    self.stream.hostName = server;
    self.stream.hostPort = port;
    self.stream.myJID = [XMPPJID jidWithString:username];

    // Should dump this off on a queue rather than running synchronously
	NSError *error = nil;
	if (![self.stream connectWithTimeout:XMPPStreamTimeoutNone error:&error]) {
		NSLog(@"Error connecting: %@", error);
        [self.connectSignal sendError:error]; // this doesn't actually work since it isn't stored anywhere
	}

    return self.connectSignal;
}

- (RACSignal *)connectAndRegisterOnServer:(NSString *)server
                                     port:(uint16_t)port
                                 username:(NSString *)username
                                 password:(NSString *)password
{
    self.createAccount = YES;
    return [self connectToServer:server port:port username:username password:password];
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
    if (self.createAccount) {
        [self.stream registerWithPassword:self.password error:nil];
        return;
    }

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

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error {
    [self.connectSignal sendError:[NSError errorWithDomain:@"WHXMPPWrapper" code:0 userInfo:@{}]];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {
	if ([message isChatMessageWithBody]) {
        [self.messages sendNext:[[message elementForName:@"body"] stringValue]];
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
