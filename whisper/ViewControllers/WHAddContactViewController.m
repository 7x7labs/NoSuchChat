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
#import "WHAlert.h"
#import "WHChatClient.h"
#import "WHKeyExchangePeer.h"
#import "WHPeerList.h"

#import <EXTScope.h>
#import <Reachability/Reachability.h>

@interface WHAddContactViewController () <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UITableView *possibleContacts;
@property (weak, nonatomic) IBOutlet UIView *browsingPanel;
@property (weak, nonatomic) IBOutlet UIView *disableWifiPanel;

@property (nonatomic, strong) WHPeerList *peerList;
@property (nonatomic, strong) Reachability *reach;
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

    [RACAbleWithStart(self.peerList, peers) subscribeNext:^(NSArray *peers) {
        @strongify(self)
        
        self.possibleContacts.hidden = peers.count == 0;
        self.browsingPanel.hidden = peers.count != 0;
    }];
    
    self.reach = [Reachability reachabilityForLocalWiFi];
    self.reach.reachableOnWWAN = NO;

    self.reach.reachableBlock = ^(Reachability *reach) {
        @strongify(self)
        [self toggleAdvertising];
    };
    
    self.reach.unreachableBlock = ^(Reachability *reach) {
        @strongify(self)
        [self toggleAdvertising];
    };
    
    [self.reach startNotifier];
    [self toggleAdvertising];
}

- (void)viewDidDisappear:(BOOL)animated {
    self.client.advertising = NO;
}

- (void)viewDidUnload {
    self.reach = nil;
}

- (void)toggleAdvertising {
    BOOL enabled = [self shouldAdvertise];
    self.client.advertising = enabled;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.disableWifiPanel.hidden = enabled;
    });
}

- (BOOL)shouldAdvertise {
#if DEBUG
    return YES;
#endif
    
    // AFAIK, there's no public API that reliably detects bluetooth.
    BOOL bluetoothEnabled = YES;
    BOOL wifiEnabled = [self.reach isReachableViaWiFi];
    
    return bluetoothEnabled && !wifiEnabled;
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
    WHAddContactTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    WHKeyExchangePeer *peer = self.peerList.peers[indexPath.row];
    [cell setupWithPeer:peer];
    
    return cell;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    WHAddContactTableViewCell *cell = (WHAddContactTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
    cell.connecting = YES;
    
    [[[self.peerList.peers[indexPath.row] connectWithJid:self.client.jid]
     deliverOn:[RACScheduler mainThreadScheduler]]
     subscribeError:^(NSError *error) {
         cell.connecting = false;
         [WHAlert alertWithMessage:[error localizedDescription]];
     } completed:^{
         cell.connecting = false;
         [self.navigationController popViewControllerAnimated:YES];
     }];
}

@end
