//
//  WHSettingsViewController.m
//  whisper
//
//  Created by Thomas Goyne on 7/26/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHSettingsViewController.h"

#import "WHChatClient.h"

#import <ReactiveCocoa/ReactiveCocoa.h>

@interface WHSettingsViewController ()
@property (weak, nonatomic) IBOutlet UITextField *displayName;
@end

@implementation WHSettingsViewController
- (void)viewDidLoad {
    [super viewDidLoad];

    RAC(self.displayName.text) = RACAbleWithStart(self.client.displayName);
    RAC(self.client.displayName) = self.displayName.rac_textSignal;
}
@end
