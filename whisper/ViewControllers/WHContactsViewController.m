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

#import <ReactiveCocoa/NSNotificationCenter+RACSupport.h>

@interface WHContactsViewController ()
@property (nonatomic, strong) NSArray *contacts;

@property (nonatomic, weak) Contact *sequeContact;
@end

@implementation WHContactsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.contacts = [Contact all];
    RAC(self.contacts) =
        [[NSNotificationCenter.defaultCenter
          rac_addObserverForName:NSManagedObjectContextObjectsDidChangeNotification
          object:nil]
         map:^(NSNotification *_) { return [Contact all]; }];


    [RACAble(self.contacts) subscribeNext:^(id _) {
        [self.tableView reloadData];
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"show chat"])
        ((WHChatViewController *)segue.destinationViewController).contact = self.sequeContact;
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
