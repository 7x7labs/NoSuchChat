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
#import <Reachability/Reachability.h>

@interface WHAddContactViewController () <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UITableView *possibleContacts;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UILabel *statusMessage;

@property (nonatomic, strong) WHPeerList *peerList;
@property (nonatomic, strong) Reachability *reach;
@end

@implementation WHAddContactViewController
- (void)viewDidLoad {
    [super viewDidLoad];

    self.possibleContacts.dataSource = self;
    self.possibleContacts.delegate = self;

    @weakify(self)
    RAC(self, peerList) = [RACAble(self.client, peerID) map:^id(MCPeerID *peerID) {
        if (!peerID) return nil;
        @strongify(self)
        return [[WHPeerList alloc] initWithOwnPeerID:peerID
                                         contactJids:[NSSet setWithArray:[self.contacts valueForKey:@"jid"]]];
    }];

    [RACAble(self, peerList.peers) subscribeNext:^(id _) {
        @strongify(self)
        [self.possibleContacts reloadData];
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

    NSString *message = enabled ? @"Looking for Whisper contacts ..." : @"Please disable Wifi and enable Bluetooth.";
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.client.advertising = enabled;
        self.statusMessage.text = message;
        self.activityIndicator.hidden = !enabled;
        self.possibleContacts.hidden = !enabled;
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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    cell.textLabel.text = [self.peerList.peers[indexPath.row] name];
    return cell;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.statusMessage.text = @"Connecting to contact ...";

    [[[self.peerList.peers[indexPath.row] connectWithJid:self.client.jid]
     deliverOn:[RACScheduler mainThreadScheduler]]
     
     subscribeError:^(NSError *error) {
         [WHAlert alertWithMessage:[error localizedDescription]];
         self.activityIndicator.hidden = false;
         self.statusMessage.text = @"Looking for Whisper contacts ...";
     } completed:^{
         [self.navigationController popViewControllerAnimated:YES];
     }];
}

@end
