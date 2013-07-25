//
//  WHChatViewController.m
//  whisper
//
//  Created by Thomas Goyne on 7/16/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHChatViewController.h"

#import "Contact.h"
#import "WHChatClient.h"

#import <EXTScope.h>
#import <ReactiveCocoa/NSNotificationCenter+RACSupport.h>

@interface WHChatViewController () <UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UITextField *message;
@property (weak, nonatomic) IBOutlet UIButton *send;
@property (weak, nonatomic) IBOutlet UITableView *chatLog;

@property (nonatomic, strong) NSArray *messages;
@end

@implementation WHChatViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    @weakify(self);

    self.title = self.contact.name;

    RAC(self.messages) = [RACAbleWithStart(self.contact, messages)
                          map:^id(id value) {
                            return [value sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc]
                                                                         initWithKey:@"sent" ascending:NO]]];
                          }];
    [RACAble(self.messages) subscribeNext:^(id _) {
        @strongify(self)
        [self.chatLog reloadData];
    }];

    RAC(self.send, enabled) = [self.message.rac_textSignal
                               map:^(NSString *text) { return @([text length] > 0); }];

    self.chatLog.dataSource = self;
}

- (IBAction)sendMessage {
    [self.client sendMessage:self.message.text to:self.contact];
    self.message.text = @"";
}

#pragma mark UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.messages count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = [self.messages[indexPath.row] text];
    return cell;
}
@end
