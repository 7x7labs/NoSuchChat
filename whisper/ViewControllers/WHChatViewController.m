//
//  WHChatViewController.m
//  whisper
//
//  Created by Thomas Goyne on 7/16/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHChatViewController.h"

#import "Contact.h"
#import "Message.h"
#import "WHAlert.h"
#import "WHChatClient.h"

#import <EXTScope.h>
#import <SDWebImage/UIImageView+WebCache.h>

@interface WHChatViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *keyboardHeight;
@property (weak, nonatomic) IBOutlet UIButton *send;
@property (weak, nonatomic) IBOutlet UITableView *chatLog;
@property (weak, nonatomic) IBOutlet UITextField *message;
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
                                                                         initWithKey:@"sent" ascending:YES]]];
                          }];
    [RACAble(self.messages) subscribeNext:^(id _) {
        @strongify(self)
        [self.chatLog reloadData];
        [self scrollToEnd:self.chatLog];
    }];

    RAC(self.send, enabled) = [self.message.rac_textSignal
                               map:^(NSString *text) { return @([text length] > 0); }];

    self.chatLog.dataSource = self;
    self.chatLog.delegate = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (IBAction)sendMessage {
    if ([self.message.text length] == 0)
        return;
    
    [[self.client sendMessage:self.message.text to:self.contact]
     subscribeError:^(NSError *error) {
         [WHAlert alertWithMessage:[error description]];
     }];
    self.message.text = @"";
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendMessage];
    return NO;
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    NSTimeInterval animationDuration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];

    CGRect keyboardFrame = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat height = keyboardFrame.size.height;
    
    self.keyboardHeight.constant = height;
    [self.view setNeedsUpdateConstraints];
    
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    self.keyboardHeight.constant = 0;
}

- (void)scrollToEnd:(UIScrollView *)scrollView {
    if (scrollView.contentSize.height > scrollView.frame.size.height)
    {
        CGPoint offset = CGPointMake(0, scrollView.contentSize.height - scrollView.frame.size.height);
        [scrollView setContentOffset:offset animated:YES];
    }
}

#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.messages[indexPath.row] delete];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.message resignFirstResponder];
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
    Message *message = self.messages[indexPath.row];
    
    // TODO: Better way to lookup the jid?
    NSString *jid = ([message.incoming boolValue] ? message.contact.jid : self.client.jid);
    NSURL *avatarURL = [Contact avatarURLForEmail:jid];

    UIImageView *avatarImage = (UIImageView *)[cell viewWithTag:101];
    [avatarImage setImageWithURL:avatarURL];
    
    UILabel *messageLabel = (UILabel *)[cell viewWithTag:102];
    messageLabel.text = message.text;
    
    UILabel *timestampLabel = (UILabel *)[cell viewWithTag:103];
    timestampLabel.text = [self formatDate:message.sent];

//    UIImageView *bubbleImage = (UIImageView *)[cell viewWithTag:104];
//    bubbleImage.image = [[UIImage imageNamed:@"CKBubbleLeft"] stretchableImageWithLeftCapWidth:23 topCapHeight:15];
    
    cell.editing = YES;
    return cell;
}

- (NSString *)formatDate:(NSDate *)date {
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"h:mma ' on' MMM d"];
    
    NSString *dateString;
    dateString = [dateFormat stringFromDate:date];
    dateString = [dateString lowercaseString];
    
    return dateString;
}

@end
