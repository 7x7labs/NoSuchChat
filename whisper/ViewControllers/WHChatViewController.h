//
//  WHChatViewController.h
//  whisper
//
//  Created by Thomas Goyne on 7/16/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import <UIKit/UIKit.h>

@class Contact;

@interface WHChatViewController : UIViewController
@property (nonatomic, strong) Contact *contact;
@end
