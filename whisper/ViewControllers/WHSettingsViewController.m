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

#import <ReactiveCocoa/ReactiveCocoa.h>

@interface WHSettingsViewController ()
@property (weak, nonatomic) IBOutlet UITextField *displayName;
@property (weak, nonatomic) IBOutlet UITableView *availabilityTable;
@property (weak, nonatomic) IBOutlet UITextView *statusMessage;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;

@property (nonatomic, strong) WHSettingsViewModel *viewModel;
@property (nonatomic, strong) WHCheckList *availabilityCheckList;
@end

@implementation WHSettingsViewController
- (void)viewDidLoad {
    [super viewDidLoad];

    self.viewModel = [[WHSettingsViewModel alloc] initWithClient:self.client];
    self.availabilityCheckList = [[WHCheckList alloc]
                                  initWithTableView:self.availabilityTable
                                  initialValue:self.viewModel.availability
                                  labels:@[@"Available",
                                           @"Away",
                                           @"Want to chat",
                                           @"Do not disturb"]
                                  values:@[@"",
                                           @"away",
                                           @"chat",
                                           @"dnd"]];


    RACBind(self.displayName.text) = RACBind(self.viewModel.displayName);
    RACBind(self.statusMessage.text) = RACBind(self.viewModel.statusMessage);
    RACBind(self.viewModel.availability) = RACBind(self.availabilityCheckList.value);

    RAC(self.viewModel.displayName) = self.displayName.rac_textSignal;
    RAC(self.viewModel.statusMessage) = self.statusMessage.rac_textSignal;

    self.saveButton.rac_command = [RACCommand commandWithCanExecuteSignal:RACAbleWithStart(self.viewModel.valid)];
    [self.saveButton.rac_command subscribeNext:^(id _) {
        [self.viewModel save];
    }];
}

@end
