//
//  WHChatViewTableCell.h
//  whisper
//
//  Created by Bill Mers on 8/29/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "Message.h"

#import <UIKit/UIKit.h>

@interface WHChatViewTableCell : UITableViewCell

- (void)setupWithMessage:(Message *)message userJid:(NSString *)userJid;
+ (CGFloat)calculateHeight:(Message *)message;

@end
