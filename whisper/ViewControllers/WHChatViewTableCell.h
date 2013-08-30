//
//  WHChatViewTableCell.h
//  whisper
//
//  Created by Bill Mers on 8/29/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Message;

@interface WHChatViewTableCell : UITableViewCell

- (void)setupWithMessage:(Message *)message userJid:(NSString *)userJid;
+ (CGFloat)calculateHeight:(Message *)message;

@end
