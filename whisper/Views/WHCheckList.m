//
//  WHCheckList.m
//  whisper
//
//  Created by Thomas Goyne on 7/30/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHCheckList.h"

#import <ReactiveCocoa/ReactiveCocoa.h>

@interface WHCheckList () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, weak) UITableView *tableView;
@property (nonatomic, strong) NSString *value;

@property (nonatomic, strong) NSArray *labels;
@property (nonatomic, strong) NSArray *values;
@end

@implementation WHCheckList
- (instancetype)initWithTableView:(UITableView *)tableView
                     initialValue:(NSString *)value
                           labels:(NSArray *)labels
                           values:(NSArray *)values
{
    if (!(self = [super init])) return self;
    self.tableView = tableView;
    self.value = value;
    self.labels = labels;
    self.values = values;

    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView reloadData];

    for (NSUInteger i = 0; i < [self.values count]; ++i) {
        if ([self.values[i] isEqualToString:self.value]) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
            [self.tableView selectRowAtIndexPath:indexPath
                                        animated:NO
                                  scrollPosition:0];
            [self.tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
            break;
        }
    }

    return self;
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.labels count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    cell.textLabel.text = self.labels[indexPath.row];
    return cell;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
    self.value = self.values[indexPath.row];
}

@end
