//
//  WHSettingsViewController.m
//  whisper
//
//  Created by Thomas Goyne on 7/26/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHSettingsViewController.h"

#import "WHAlert.h"
#import "WHSettingsViewModel.h"

#import <libextobjc/EXTScope.h>

@interface WHSettingsViewController ()
@property (weak, nonatomic) IBOutlet UITextField *displayName;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *cancelButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;

@property (nonatomic, strong) WHSettingsViewModel *viewModel;
@end

@implementation WHSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    @weakify(self)

    self.viewModel = [[WHSettingsViewModel alloc] initWithClient:self.client];

    RAC(self.displayName, text) = [RACAbleWithStart(self.viewModel, displayName)
                                   filter:^BOOL(NSString *text) {
                                       return [text rangeOfString:@"\uFFFC"].location == NSNotFound;
                                   }];
    RAC(self.viewModel.displayName) = self.displayName.rac_textSignal;

    self.saveButton.rac_command = [RACCommand commandWithCanExecuteSignal:RACAbleWithStart(self.viewModel.valid)];
    [self.saveButton.rac_command subscribeNext:^(id _) {
        @strongify(self)
        [self.viewModel save];
        [self.navigationController popViewControllerAnimated:YES];
    }];
    
    self.cancelButton.rac_command = [RACCommand command];
    [self.cancelButton.rac_command subscribeNext:^(id _) {
        @strongify(self)
        [self.navigationController popViewControllerAnimated:YES];
    }];
}

- (IBAction)reset {
    [[WHAlert alertWithMessage:@"This action will delete all application data, including contacts, messages, and private keys.  Do you want to proceed?"
                         title:@"Reset Application"
                       buttons:@[@"Cancel", @"Reset"]]
     subscribeNext:^(NSNumber *button) {
         if ([button intValue] != 1) return;
         [self.viewModel deleteAll];
         UINavigationController *nc = self.navigationController;
         NSUInteger vcCount = [[nc viewControllers] count];
         for (NSUInteger i = 0; i < vcCount - 1; ++i)
             [nc popViewControllerAnimated:NO];
     }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)showChatWithJid:(NSString *)jid {
    NSArray *vcs = [self.navigationController viewControllers];
    [self.navigationController popViewControllerAnimated:NO];
    [vcs[[vcs count] - 2] showChatWithJid:jid];
}

@end
