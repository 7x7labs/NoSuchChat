//
//  WHChatViewTableCell.m
//  whisper
//
//  Created by Bill Mers on 8/29/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHChatViewTableCell.h"
#import "Contact.h"
#import "UIView+Position.h"

#import <SDWebImage/UIImageView+WebCache.h>

@interface WHChatViewTableCell ()
@property (weak, nonatomic) IBOutlet UIImageView *avatarImage;
@property (weak, nonatomic) IBOutlet UIImageView *bubbleImage;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (weak, nonatomic) IBOutlet UILabel *timestampLabel;

@property (strong, nonatomic) Message *message;
@property (strong, nonatomic) NSString *jid;
@end

@implementation WHChatViewTableCell

- (void)setupWithMessage:(Message *)message userJid:(NSString *)userJid
{
    self.editing = YES;
    self.jid     = [message incomingValue] ? message.contact.jid : userJid;
    self.message = message;
    
    [self populateControls];
}

- (BOOL)incoming
{
    return [self.message incomingValue];
}

- (void)populateControls
{
    NSURL *avatarURL = [Contact avatarURLForEmail:self.jid];
    [self.avatarImage setImageWithURL:avatarURL];

    self.messageLabel.text = self.message.text;
    self.timestampLabel.text = [self formatDate:self.message.sent];

    self.messageLabel.frameWidth = 240;
    [self.messageLabel sizeToFit];
    
    self.bubbleImage.frameWidth = self.messageLabel.frameWidth + 35;
    
    if ([self incoming]) {
        self.bubbleImage.image = [[UIImage imageNamed:@"BubbleLeft"] stretchableImageWithLeftCapWidth:23 topCapHeight:15];
    }
    else {
        self.bubbleImage.image = [[UIImage imageNamed:@"BubbleRight"] stretchableImageWithLeftCapWidth:15 topCapHeight:15];
        
        int defaultBubbleX = 272;
        self.bubbleImage.frameX = defaultBubbleX - self.bubbleImage.frameWidth;
        self.messageLabel.frameX = defaultBubbleX - self.messageLabel.frameWidth - 20;
    }
}

- (NSString *)formatDate:(NSDate *)date
{
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"h:mma MMM d"];
    
    NSString *dateString;
    dateString = [dateFormat stringFromDate:date];
    dateString = [dateString lowercaseString];
    
    return dateString;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
// iOS7 deprecated NSString sizeWithFont in favor of NSAttributedString boundingRectWithSize, however that method seems to
// ignore width contstraints.
+ (CGFloat)calculateHeight:(Message *)message
{
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue" size:15.0];
    CGSize size = [message.text sizeWithFont:font constrainedToSize:CGSizeMake(240, 1000) lineBreakMode:NSLineBreakByWordWrapping];
    
    int padding = 28;
    int height = size.height + padding;
    
    return height;
}
#pragma clang diagnostic pop

@end
