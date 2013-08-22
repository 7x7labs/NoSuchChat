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
#import "WHChatClient.h"

#import <CommonCrypto/CommonDigest.h>
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

    [super viewDidLoad];
}

- (IBAction)sendMessage {
    if ([self.message.text length] == 0)
        return;
    
    [self.client sendMessage:self.message.text to:self.contact];
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
    
    UILabel *messageLabel = (UILabel *)[cell viewWithTag:102];
    messageLabel.text = message.text;
    
    UILabel *timestampLabel = (UILabel *)[cell viewWithTag:103];
    timestampLabel.text = [self formatDate:message.sent];

    // TODO: Better way to lookup the jid?
    NSString *jid = ([message.incoming boolValue] ? message.contact.jid : self.client.jid);
    NSURL *avatarURL = [self buildGravatarURL:jid];
    UIImageView *avatarImage = (UIImageView *)[cell viewWithTag:101];
    [avatarImage setImageWithURL:avatarURL];
    
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

// TODO: Move this method to an appropriate home
- (NSURL *)buildGravatarURL:(NSString *)emailAddress {
	NSString *curatedEmail = [[emailAddress stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
							  lowercaseString];
    
	const char *cStr = [curatedEmail UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, strlen(cStr), result);
    
	NSString *md5email = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                              result[0], result[1], result[2], result[3],
                              result[4], result[5], result[6], result[7],
                              result[8], result[9], result[10], result[11],
                              result[12], result[13], result[14], result[15]
                          ];
	NSString *gravatarEndPoint = [NSString stringWithFormat:@"http://www.gravatar.com/avatar/%@?s=80&d=identicon", md5email];
    
	return [NSURL URLWithString:gravatarEndPoint];
}

@end
