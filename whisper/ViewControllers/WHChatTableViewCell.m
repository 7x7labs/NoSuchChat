//
//  WHChatTableViewCell.m
//  whisper
//
//  Created by Bill Mers on 8/29/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHChatTableViewCell.h"

#import "Contact.h"
#import "Message.h"
#import "WHAvatar.h"

#import "UIView+Position.h"

@interface WHChatTableViewCell ()
@property (weak, nonatomic) IBOutlet UIImageView *avatarImage;
@property (weak, nonatomic) IBOutlet UIImageView *bubbleImage;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (weak, nonatomic) IBOutlet UILabel *timestampLabel;

@property (strong, nonatomic) Message *message;
@property (strong, nonatomic) NSString *jid;
@property (strong, nonatomic) NSString *text;
@end

@implementation WHChatTableViewCell

- (void)setupWithMessage:(Message *)message userJid:(NSString *)userJid
{
    self.editing = YES;
    self.jid     = [message incomingValue] ? message.contact.jid : userJid;
    self.message = message;
    self.text    = message.text ?: @"<failed to decrypt message>";

    [self populateControls];
}

- (BOOL)incoming
{
    return [self.message incomingValue];
}

- (void)populateControls
{
    self.avatarImage.image = [WHAvatar avatarForEmail:self.jid];
    
    // resize labels
    self.messageLabel.text = self.text;
    self.timestampLabel.attributedText = [self formatTimestamp:self.message.sent];

    self.timestampLabel.frameWidth = 100;
    [self.timestampLabel sizeToFit];

    self.messageLabel.frameWidth = 230;
    [self.messageLabel sizeToFit];
    
    // set bubble height
    int defaultBubbleHeight = 52;
    int defaultMessageHeight = 21;
    int bubbleHeight = self.messageLabel.frameHeight - defaultMessageHeight + defaultBubbleHeight;
    self.bubbleImage.frameHeight = bubbleHeight;
    
    // set bubble width
    int widthPadding = 24;
    int messageWidth = self.messageLabel.frameWidth;
    int timestampWidth = self.timestampLabel.frameWidth;
    self.bubbleImage.frameWidth = fmaxf(timestampWidth, messageWidth) + widthPadding;
    
    if ([self incoming]) {
        self.bubbleImage.image = [[UIImage imageNamed:@"bubble-left"] stretchableImageWithLeftCapWidth:23 topCapHeight:15];
    }
    else {
        self.bubbleImage.image = [[UIImage imageNamed:@"bubble-right"] stretchableImageWithLeftCapWidth:15 topCapHeight:15];
        
        int defaultBubbleX = 272;
        self.bubbleImage.frameX = defaultBubbleX - self.bubbleImage.frameWidth;
        self.messageLabel.frameX = defaultBubbleX - self.messageLabel.frameWidth - 16;
        self.timestampLabel.frameX = defaultBubbleX - self.timestampLabel.frameWidth - 16;
    }
}

- (NSAttributedString *)formatTimestamp:(NSDate *)date
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];

    [formatter setDateFormat:@"MMM d "];
    NSString *dayString = [formatter stringFromDate:date];
    UIFont *dayFont = [UIFont fontWithName:@"HelveticaNeue-Medium" size:11.0];
    NSAttributedString *dayAttr = [[NSAttributedString alloc] initWithString:dayString
                                                                  attributes:@{NSFontAttributeName : dayFont}];

    [formatter setDateFormat:@"h:mma"];
    NSString *timeString = [[formatter stringFromDate:date] lowercaseString];
    UIFont *timeFont = [UIFont fontWithName:@"HelveticaNeue-Light" size:11.0];
    NSAttributedString *timeAttr = [[NSAttributedString alloc] initWithString:timeString
                                                                   attributes:@{NSFontAttributeName : timeFont}];

    NSMutableAttributedString *result = [dayAttr mutableCopy];
    [result appendAttributedString:timeAttr];

    return result;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
// iOS7 deprecated NSString sizeWithFont in favor of NSAttributedString boundingRectWithSize, however that method seems to
// ignore width contstraints.
+ (CGFloat)calculateHeight:(Message *)message
{
    NSString *text = message.text ?: @"";
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Light" size:17.0];
    CGSize size = [text sizeWithFont:font constrainedToSize:CGSizeMake(230, 1000) lineBreakMode:NSLineBreakByWordWrapping];
    
    int defaultRowHeight = 58;
    int defaultMessageHeight = 21;

    int height = defaultRowHeight - defaultMessageHeight + size.height;
    
    return height;
}
#pragma clang diagnostic pop

@end
