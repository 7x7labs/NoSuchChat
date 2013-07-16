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

#import <ReactiveCocoa/NSNotificationCenter+RACSupport.h>

@interface WHContactsViewController ()
@property (nonatomic, strong) NSArray *contacts;
@end

@implementation WHContactsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    RAC(self.contacts) =
        [[NSNotificationCenter.defaultCenter
          rac_addObserverForName:NSManagedObjectContextObjectsDidChangeNotification
          object:nil]
         map:^(NSNotification *_) { return [Contact all]; }];


    [RACAble(self.contacts) subscribeNext:^(id _) {
        [self.tableView reloadData];
    }];

    if ([self.contacts count] == 0) {
        [Contact createWithName:@"a"];
        [Contact createWithName:@"b"];
        [Contact createWithName:@"c"];
    }
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

@end
