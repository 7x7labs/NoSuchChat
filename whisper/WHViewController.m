//
//  WHViewController.m
//  whisper
//
//  Created by Thomas Goyne on 7/9/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHViewController.h"

#import "XMPP.h"

@interface WHViewController ()
@property (nonatomic, strong) XMPPStream *stream;
@end

@implementation WHViewController
- (void)viewDidLoad {
    [super viewDidLoad];

    self.stream = [XMPPStream new];
	[self.stream addDelegate:self delegateQueue:dispatch_get_main_queue()];

	[self.stream setHostName:@"talk.google.com"];
	[self.stream setHostPort:5222];

	[self.stream setMyJID:[XMPPJID jidWithString:@"thomas@7x7labs.com"]];

	NSError *error = nil;
	if (![self.stream connectWithTimeout:XMPPStreamTimeoutNone error:&error]) {
		[[[UIAlertView alloc] initWithTitle:@"Error connecting"
		                                                    message:@"See console for error details."
		                                                   delegate:nil
		                                          cancelButtonTitle:@"Ok"
		                                          otherButtonTitles:nil]
         show];

		NSLog(@"Error connecting: %@", error);
	}
}

- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings {
    settings[(NSString *)kCFStreamSSLAllowsAnyRoot] = @YES;
    settings[(NSString *)kCFStreamSSLPeerName] = [NSNull null];
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender {
	NSError *error = nil;
	if (![self.stream authenticateWithPassword:@"" error:&error]) {
		NSLog(@"Error authenticating: %@", error);
	}
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender {
	[self.stream sendElement:[XMPPPresence presence]];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message {
	if ([message isChatMessageWithBody]) {
		NSString *body = [[message elementForName:@"body"] stringValue];

        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"message"
                                                          message:body
                                                         delegate:nil
                                                cancelButtonTitle:@"Ok"
                                                otherButtonTitles:nil];
        [alertView show];
	}
}
@end
