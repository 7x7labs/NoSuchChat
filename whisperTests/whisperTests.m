//
//  whisperTests.m
//  whisperTests
//
//  Created by Thomas Goyne on 7/9/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "Contact.h"
#import "Message.h"
#import "WHCoreData.h"

#import "Specta.h"
#define EXP_SHORTHAND
#import "Expecta.h"

SpecBegin(WhisperTests)

describe(@"Contact", ^{
    beforeEach(^{
        [(id)[[UIApplication sharedApplication] delegate] initTestContext];
    });

    it(@"should initially return an empty array from all", ^{
        expect([Contact all]).to.haveCountOf(0);
    });

    it(@"should be able to create new contacts with the specified name", ^{
        Contact *contact = [Contact createWithName:@"abc"];
        expect(contact).notTo.beNil();
        expect(contact.name).to.equal(@"abc");
    });

    it(@"should return newly created contacts from all", ^{
        [Contact createWithName:@"def"];
        NSArray *all = [Contact all];
        expect(all).to.haveCountOf(1);
        expect([all[0] name]).to.equal(@"def");
    });

    describe(@"messages", ^{
        __block Contact *contact;
        beforeEach(^{
            contact = [Contact createWithName:@"test contact"];
        });

        it(@"should initially be empty", ^{
            expect(contact.messages).to.haveCountOf(0);
        });

        it(@"should return newly sent messages", ^{
            [contact addSentMessage:@"test message" date:[NSDate date]];
            expect(contact.messages).to.haveCountOf(1);
            expect([[contact.messages anyObject] text]).to.equal(@"test message");
        });

        it(@"should return newly received messages", ^{
            [contact addReceivedMessage:@"test message" date:[NSDate date]];
            expect(contact.messages).to.haveCountOf(1);
            expect([[contact.messages anyObject] text]).to.equal(@"test message");
        });

        it(@"should sort messages by sent time in descending order", ^{
            for (int i = 0; i < 10; ++i)
                [contact addReceivedMessage:@"test message"
                                       date:[NSDate dateWithTimeIntervalSinceNow:-(int)(arc4random() % 10000)]];
            expect(contact.messages).to.haveCountOf(10);
            NSDate *prevDate = [NSDate dateWithTimeIntervalSinceNow:1];
            for (Message *message in contact.orderedMessages) {
                expect(message.sent).to.beLessThanOrEqualTo(prevDate);
                prevDate = message.sent;
            }
        });
    });
});

SpecEnd
