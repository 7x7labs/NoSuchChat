//
//  WHAddContactViewController.m
//  whisper
//
//  Created by Thomas Goyne on 7/15/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHAddContactViewController.h"

#import "Contact.h"
#import "WHChatClient.h"
#import "WHKeyExchangePeer.h"
#import "WHPeerList.h"

#import <EXTScope.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

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

    self.peerList = [[WHPeerList alloc] initWithInfo:@{@"name": @"Display name",
                                                       @"jid": self.client.jid}];

    @weakify(self)
    [RACAble(self.peerList, peers) subscribeNext:^(id _) {
        @strongify(self)
        [self.possibleContacts reloadData];
    }];
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

    WHKeyExchangePeer *peer = self.peerList.peers[indexPath.row];
    [peer.connected subscribeCompleted:^{
        [self.navigationController popViewControllerAnimated:YES];
    }];
    [peer connect];
}
@end
