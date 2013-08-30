//
//  WHWelcomeViewController.m
//  whisper
//
//  Created by Bill Mers on 8/29/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHWelcomeViewController.h"

@interface WHWelcomeViewController ()
@property (weak, nonatomic) IBOutlet UITextField *username;
@end

@implementation WHWelcomeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self performSegueWithIdentifier:@"LoadMainNavigation" sender:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO];
}

@end
