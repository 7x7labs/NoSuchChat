//
//  WHAddContactViewController.m
//  whisper
//
//  Created by Thomas Goyne on 7/15/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHAddContactViewController.h"

#import "Contact.h"
#import "WHAddContactTableViewCell.h"
#import "WHAddContactViewModel.h"
#import "WHAlert.h"
#import "WHChatClient.h"

#import <libextobjc/EXTScope.h>

@interface WHAddContactViewController () <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UITableView *possibleContacts;
@property (weak, nonatomic) IBOutlet UIView *browsingPanel;
@property (weak, nonatomic) IBOutlet UIView *disableWifiPanel;

@property (nonatomic, strong) WHAddContactViewModel *viewModel;
@end

@implementation WHAddContactViewController
- (void)viewDidLoad {
    [super viewDidLoad];

    self.possibleContacts.dataSource = self;
    self.possibleContacts.delegate = self;

    self.viewModel = [[WHAddContactViewModel alloc]
                      initWithClient:self.client contacts:self.contacts];

    RAC(self.possibleContacts, hidden) = [RACAbleWithStart(self.viewModel, count) not];
    RAC(self.browsingPanel, hidden) = RACAbleWithStart(self.viewModel, count);
    RAC(self.disableWifiPanel, hidden) = RACAbleWithStart(self.viewModel, advertising);

    @weakify(self)
    [RACAble(self.viewModel, count) subscribeNext:^(id _) {
        @strongify(self)
        [self.possibleContacts reloadData];
    }];
}

- (void)showChatWithJid:(NSString *)jid {
    NSArray *vcs = [self.navigationController viewControllers];
    [self.navigationController popViewControllerAnimated:NO];
    [vcs[[vcs count] - 2] showChatWithJid:jid];
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.viewModel.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    WHAddContactTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    [cell setupWithPeer:self.viewModel[indexPath.row]];
    
    return cell;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[[(WHAddContactTableViewCell *)[tableView cellForRowAtIndexPath:indexPath] connect]
     deliverOn:[RACScheduler mainThreadScheduler]]
     subscribeError:^(NSError *error) {
         [WHAlert alertWithMessage:[error localizedDescription]];
     } completed:^{
         [self.navigationController popViewControllerAnimated:YES];
     }];
}

@end
