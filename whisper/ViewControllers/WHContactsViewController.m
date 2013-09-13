//
//  WHContactsViewController.m
//  whisper
//
//  Created by Thomas Goyne on 7/15/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHContactsViewController.h"

#import "Contact.h"
#import "WHAddContactViewController.h"
#import "WHChatClient.h"
#import "WHChatViewController.h"
#import "WHContactListViewModel.h"
#import "WHContactTableViewCell.h"
#import "WHCoreData.h"

#import <EXTScope.h>

@interface WHContactsViewController ()
@property (nonatomic, strong) IBOutlet UIView *tableHeader;

@property (nonatomic, strong) WHChatClient *client;
@property (nonatomic, strong) WHContactListViewModel *viewModel;

@property (nonatomic, weak) Contact *sequeContact;
@end

@implementation WHContactsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.viewModel = [[WHContactListViewModel alloc] initWithClient:self.client];

    @weakify(self)
    [RACAble(self.viewModel, count) subscribeNext:^(id _) {
        @strongify(self)
        [self.tableView reloadData];
    }];

    [self.tableView rac_liftSelector:@selector(setTableHeaderView:)
                         withObjects:[RACSignal if:RACAbleWithStart(self.client, connected)
                                              then:[RACSignal return:nil]
                                              else:[RACSignal return:self.tableHeader]]];

    if (self.contactJid) {
        [self showChatWithJid:self.contactJid];
        self.contactJid = nil;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([self.client.contacts count] == 0)
        [self performSegueWithIdentifier:@"add contact" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    id dest = segue.destinationViewController;
    if ([dest respondsToSelector:@selector(setContact:)])
        [dest setContact:self.sequeContact];
    if ([dest respondsToSelector:@selector(setClient:)])
        [dest setClient:self.client];
}

- (void)showChatWithJid:(NSString *)jid {
    self.sequeContact = [Contact contactForJid:jid managedObjectContext:[WHCoreData managedObjectContext]];
    if (self.sequeContact)
        [self performSegueWithIdentifier:@"show chat" sender:self];
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.viewModel.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    WHContactTableViewCell *cell = (WHContactTableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    [cell switchToViewModel:self.viewModel[indexPath.row]];
    cell.editing = YES;
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.viewModel deleteContactAtIndex:indexPath.row];
}

#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.sequeContact = [self.viewModel rawContactAtIndex:indexPath.row];
    [self performSegueWithIdentifier:@"show chat" sender:self];
}

@end
