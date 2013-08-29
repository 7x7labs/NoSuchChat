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
#import "WHChatViewModel.h"

#import <EXTScope.h>
#import <SDWebImage/UIImageView+WebCache.h>
#import "UIView+Position.h"

@interface WHChatViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UIButton *send;
@property (weak, nonatomic) IBOutlet UITableView *chatLog;
@property (weak, nonatomic) IBOutlet UITextField *message;
@property (weak, nonatomic) IBOutlet UIView *inputView;

@property (nonatomic, strong) WHChatViewModel *viewModel;
@end

@implementation WHChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    @weakify(self);
    
    RACBind(self.title) = RACBind(self.contact.name);
    self.viewModel = [[WHChatViewModel alloc] initWithClient:self.client
                                                     contact:self.contact];
    
    [RACAble(self.viewModel, messages) subscribeNext:^(id _) {
        @strongify(self)
        [self.chatLog reloadData];
        [self scrollToBottom:self.chatLog animated:YES];
    }];
    
    RACBind(self.send, enabled) = RACBind(self.viewModel, canSend);
    RACBind(self.message, text) = RACBind(self.viewModel, message);
    RAC(self.viewModel, message) = self.message.rac_textSignal;
    
    self.chatLog.dataSource = self;
    self.chatLog.delegate = self;
    
    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard)];
    gestureRecognizer.cancelsTouchesInView = NO;
    [self.chatLog addGestureRecognizer:gestureRecognizer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(repositionForKeyboard:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(repositionForKeyboard:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (IBAction)sendMessage {
    [self.viewModel send];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self.viewModel send];
    return NO;
}

- (void)hideKeyboard {
    [self.view endEditing:YES];
}

- (void)repositionForKeyboard:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    NSTimeInterval animationDuration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    CGRect keyboardFrame = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat height = keyboardFrame.size.height;

    bool showing = [notification.name isEqualToString:@"UIKeyboardWillShowNotification"];
    if (showing) height = -1 * height;
    
    [UIView animateWithDuration:animationDuration animations:^{
        self.inputView.frameY += height;
        self.chatLog.frameHeight += height;
    }];
    
    [self scrollToBottom:self.chatLog animated:YES];
}

- (void)scrollToBottom:(UITableView *)table animated:(BOOL)animated {
    int lastSection = [table numberOfSections] - 1;
    int lastRow = [table numberOfRowsInSection:lastSection] - 1;
    
    if (lastSection == -1) return;
    if (lastRow == -1) return;
    
    NSIndexPath *scrollIndexPath = [NSIndexPath indexPathForRow:lastRow inSection:lastSection];
    [table scrollToRowAtIndexPath:scrollIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:animated];
}

#pragma mark UITableViewDelegate
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.viewModel.messages[indexPath.row] delete];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.message resignFirstResponder];
}

#pragma mark UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.viewModel.messages count];
}

// TODO: Refactor this .. it makes me cringe so much I don't even know where to begin.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    Message *message = self.viewModel.messages[indexPath.row];
    UIFont *font = [UIFont fontWithName:@"Helvetica Neue" size:15.0];

    // iOS7 deprecated NSString sizeWithFont in favor of NSAttributedString boundingRectWithSize, however that method seems to
    // ignore width contstraints.
    CGSize size = [message.text sizeWithFont:font constrainedToSize:CGSizeMake(265, FLT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
    int height = size.height + 25;
    if (height < 44) height = 44;

    return height;
}
#pragma clang diagnostic pop

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    Message *message = self.viewModel.messages[indexPath.row];
    NSString *cellIdentifier = [message.incoming boolValue] ? @"IncomingChatCell" : @"OutgoingChatCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    
    // TODO: Better way to lookup the jid?
    NSString *jid = [message.incoming boolValue] ? message.contact.jid : self.client.jid;
    NSURL *avatarURL = [Contact avatarURLForEmail:jid];

    UIImageView *avatarImage = (UIImageView *)[cell viewWithTag:101];
    [avatarImage setImageWithURL:avatarURL];
    
    UILabel *messageLabel = (UILabel *)[cell viewWithTag:102];
    messageLabel.text = message.text;
    messageLabel.frameWidth = 265;
    
    UILabel *timestampLabel = (UILabel *)[cell viewWithTag:103];
    timestampLabel.text = [self formatDate:message.sent];
    timestampLabel.frameY = cell.frameHeight - 18;

//    UIImageView *bubbleImage = (UIImageView *)[cell viewWithTag:104];
//    bubbleImage.image = [[UIImage imageNamed:@"CKBubbleLeft"] stretchableImageWithLeftCapWidth:23 topCapHeight:15];
    
    cell.editing = YES;

    return cell;
}

- (NSString *)formatDate:(NSDate *)date {
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"h:mma MMM d"];
    
    NSString *dateString;
    dateString = [dateFormat stringFromDate:date];
    dateString = [dateString lowercaseString];
    
    return dateString;
}

@end
