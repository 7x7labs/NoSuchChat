//
//  WHXMPPCapabilities.m
//  whisper
//
//  Created by Thomas Goyne on 8/7/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHXMPPCapabilities.h"

#import "XMPP.h"
#import "NSData+XMPP.h"

NSString * const kXmlnsDisco = @"http://jabber.org/protocol/disco#info";
NSString * const kXmlnsCaps = @"http://jabber.org/protocol/caps";
NSString * const kDiscoNodePrefix = @"http://whisper.7x7-labs.com";

@interface WHXMPPCapabilities ()
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) XMPPStream *stream;
@property (nonatomic, strong) NSXMLElement *capabilitiesFull;
@property (nonatomic, strong) NSXMLElement *capabilitiesHash;
@end

@implementation WHXMPPCapabilities
- (void)dealloc {
    [self.stream removeDelegate:self];
}

- (instancetype)initWithStream:(XMPPStream *)stream {
    if (!(self = [super init])) return self;

    self.queue = dispatch_queue_create("com.7x7-labs.whisper.xmpp-capabilities", 0);
    self.stream = stream;
    [stream addDelegate:self delegateQueue:self.queue];

    // Features MUST be unique and sorted by 'var'
    // Don't put < or &lt; in var since we don't bother escaping them
    NSString *capabilitiesQueryXml =
	@"<query xmlns='http://jabber.org/protocol/disco#info'>"
	@"  <feature var='http://jabber.org/protocol/caps'/>"
    @"  <feature var='http://jabber.org/protocol/disco#info'/>"
    @"  <feature var='http://jabber.org/protocol/nick'/>"
    @"  <feature var='http://jabber.org/protocol/nick+notify'/>"
	@"</query>";

    NSError *error;
    self.capabilitiesFull = [[NSXMLElement alloc] initWithXMLString:capabilitiesQueryXml
                                                              error:&error];
    NSAssert(!error, @"Error parsing hardcoded capabilities XML: %@", error);

    // Could just hardcode the hash too but then we'd need a script to update it...
	NSMutableString *var = [NSMutableString string];
	for (NSXMLElement *feature in [self.capabilitiesFull elementsForName:@"feature"])
		[var appendFormat:@"%@<", [feature attributeStringValueForName:@"var"]];

	NSData *data = [var dataUsingEncoding:NSUTF8StringEncoding];
	NSString *hash = [[data xmpp_sha1Digest] xmpp_base64Encoded];

	// <c xmlns="http://jabber.org/protocol/caps"
	//     hash="sha-1"
	//     node="http://whisper.7x7-labs.com"
	//     ver="<base64-hash>"/>
    self.capabilitiesHash = [NSXMLElement elementWithName:@"c" xmlns:kXmlnsCaps];
    [self.capabilitiesHash addAttributeWithName:@"hash" stringValue:@"sha-1"];
    [self.capabilitiesHash addAttributeWithName:@"node" stringValue:kDiscoNodePrefix];
    [self.capabilitiesHash addAttributeWithName:@"ver" stringValue:hash];

    return self;
}

#pragma mark - XMPPStreamDelegate
- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq {
	// Disco Request:
	//
	// <iq from="juliet@capulet.lit/chamber" type="get">
	//   <query xmlns="http://jabber.org/protocol/disco#info"/>
	// </iq>
	NSXMLElement *query = [iq elementForName:@"query" xmlns:kXmlnsDisco];
	if (!query) return NO;

    // We never query for capabilities, so we don't care about anything but incoming requests
    if (![[iq type] isEqualToString:@"get"]) return NO;

    NSString *node = [query attributeStringValueForName:@"node"];
    if (node && ![node hasPrefix:kDiscoNodePrefix]) return NO;

    NSXMLElement *response = [self.capabilitiesFull copy];
    if (node)
        [query addAttributeWithName:@"node" stringValue:node];

    [self.stream sendElement:[XMPPIQ iqWithType:@"result"
                                             to:[iq from]
                                      elementID:[iq elementID]
                                          child:response]];
	return YES;
}

- (XMPPPresence *)xmppStream:(XMPPStream *)sender willSendPresence:(XMPPPresence *)presence {
    if (![[presence type] isEqualToString:@"available"]) return presence;

    // Inject our capabilties hash into "available" presences
    NSXMLElement *old = [presence elementForName:self.capabilitiesHash.name
                                           xmlns:self.capabilitiesHash.xmlns];
    if (old)
        [presence removeChildAtIndex:[presence.children indexOfObject:old]];
    [presence addChild:[self.capabilitiesHash copy]];

	return presence;
}
@end
