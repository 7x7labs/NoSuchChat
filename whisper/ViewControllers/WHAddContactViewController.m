//
//  WHAddContactViewController.m
//  whisper
//
//  Created by Thomas Goyne on 7/15/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHAddContactViewController.h"

#import "Contact.h"

@interface WHAddContactViewController ()
@property (weak, nonatomic) IBOutlet UITextField *name;
@end

@implementation WHAddContactViewController
- (IBAction)add {
    [Contact createWithName:self.name.text];
    [self.navigationController popViewControllerAnimated:YES];
}
@end
