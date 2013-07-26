//
//  WHContactsViewController.m
//  whisper
//
//  Created by Thomas Goyne on 7/15/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHContactsViewController.h"

#import "Contact.h"
#import "WHCoreData.h"
#import "WHChatViewController.h"
#import "WHChatClient.h"

#import <EXTScope.h>
#import <ReactiveCocoa/NSNotificationCenter+RACSupport.h>

@interface WHContactsViewController ()
@property (nonatomic, strong) NSArray *contacts;
@property (nonatomic, strong) WHChatClient *client;

@property (nonatomic, weak) Contact *sequeContact;
@end

@implementation WHContactsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.client = [WHChatClient clientForServer:kXmppServerHost port:5222];

    @weakify(self)
    RAC(self.contacts) = RACAbleWithStart(self.client, contacts);
    [RACAble(self.contacts) subscribeNext:^(id _) {
        @strongify(self)
        [self.tableView reloadData];
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    id dest = segue.destinationViewController;
    if ([dest respondsToSelector:@selector(setContact:)])
        [dest setContact:self.sequeContact];
    if ([dest respondsToSelector:@selector(setClient:)])
        [dest setClient:self.client];
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.contacts count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    cell.textLabel.text = [self.contacts[indexPath.row] name];
    return cell;
}

#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.sequeContact = self.contacts[indexPath.row];
    [self performSegueWithIdentifier:@"show chat" sender:self];
}
@end
