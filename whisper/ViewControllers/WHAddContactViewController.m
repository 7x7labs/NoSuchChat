//
//  WHAddContactViewController.m
//  whisper
//
//  Created by Thomas Goyne on 7/15/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHAddContactViewController.h"

#import "WHAlert.h"
#import "WHChatClient.h"
#import "WHKeyExchangePeer.h"
#import "WHPeerList.h"

#import <EXTScope.h>

@interface WHAddContactViewController () <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UITableView *possibleContacts;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@property (nonatomic, strong) WHPeerList *peerList;
@end

@implementation WHAddContactViewController
- (void)viewDidLoad {
    [super viewDidLoad];

    self.possibleContacts.dataSource = self;
    self.possibleContacts.delegate = self;

    self.peerList = [[WHPeerList alloc] initWithOwnPeerID:self.client.peerID
                                              contactJids:[NSSet setWithArray:[self.contacts valueForKey:@"jid"]]];

    @weakify(self)
    [RACAble(self.peerList, peers) subscribeNext:^(id _) {
        @strongify(self)
        [self.possibleContacts reloadData];
    }];

    self.client.advertising = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    self.client.advertising = NO;
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.peerList.peers count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    cell.textLabel.text = [self.peerList.peers[indexPath.row] name];
    return cell;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.activityIndicator startAnimating];
    self.activityIndicator.hidden = NO;

    [[[self.peerList.peers[indexPath.row] connectWithJid:self.client.jid]
     deliverOn:[RACScheduler mainThreadScheduler]]
     subscribeError:^(NSError *error) {
         [WHAlert alertWithMessage:[error localizedDescription]];
     } completed:^{
         [self.navigationController popViewControllerAnimated:YES];
     }];
}
@end
