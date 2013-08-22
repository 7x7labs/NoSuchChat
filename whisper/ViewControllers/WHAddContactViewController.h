//
//  WHAddContactViewController.h
//  whisper
//
//  Created by Thomas Goyne on 7/15/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import <UIKit/UIKit.h>

@class WHChatClient;

@interface WHAddContactViewController : UIViewController
@property (nonatomic, strong) WHChatClient *client;
@property (nonatomic, strong) NSArray *contacts;
@end
