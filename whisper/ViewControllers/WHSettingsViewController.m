//
//  WHSettingsViewController.m
//  whisper
//
//  Created by Thomas Goyne on 7/26/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHSettingsViewController.h"

#import "WHCheckList.h"
#import "WHSettingsViewModel.h"

@interface WHSettingsViewController ()
@property (weak, nonatomic) IBOutlet UITextField *displayName;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;

@property (nonatomic, strong) WHSettingsViewModel *viewModel;
@end

@implementation WHSettingsViewController
- (void)viewDidLoad {
    [super viewDidLoad];

    self.viewModel = [[WHSettingsViewModel alloc] initWithClient:self.client];

    RACBind(self.displayName.text) = RACBind(self.viewModel.displayName);
    RAC(self.viewModel.displayName) = self.displayName.rac_textSignal;

    self.saveButton.rac_command = [RACCommand commandWithCanExecuteSignal:RACAbleWithStart(self.viewModel.valid)];
    [self.saveButton.rac_command subscribeNext:^(id _) {
        [self.viewModel save];
    }];
}

@end
