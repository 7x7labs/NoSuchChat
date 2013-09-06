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
#import "UIView+Position.h"
#import "WHAlert.h"
#import "WHChatClient.h"
#import "WHCoreData.h"
#import "WHChatViewModel.h"
#import "WHChatTableViewCell.h"

#import <libextobjc/EXTScope.h>
#import <ReactiveCocoa/NSNotificationCenter+RACSupport.h>

@interface WHChatViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UIButton *send;
@property (weak, nonatomic) IBOutlet UITableView *chatLog;
@property (weak, nonatomic) IBOutlet UITextField *message;
@property (weak, nonatomic) IBOutlet UIView *messagePanel;
@property (weak, nonatomic) IBOutlet UIView *statusPanel;

@property (nonatomic, strong) WHChatViewModel *viewModel;
@property (nonatomic, strong) RACSubject *cancelSignal;
@end

@implementation WHChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    @weakify(self);
    
    self.viewModel = [[WHChatViewModel alloc] initWithClient:self.client
                                                     contact:self.contact];
    self.client = nil;
    
    RACBind(self, title) = RACBind(self, viewModel.title);
    RACBind(self.send, enabled) = RACBind(self, viewModel.canSend);
    RACBind(self.statusPanel, hidden) = RACBind(self, viewModel.online);

    [RACAble(self, viewModel.messages) subscribeNext:^(id _) {
        @strongify(self)
        [self.chatLog reloadData];
        [self scrollToBottom:self.chatLog animated:YES];
    }];

    RAC(self.message, text) = [RACAbleWithStart(self, viewModel.message)
                               filter:^BOOL(NSString *text) {
                                   // The dictation stuff inserts a placeholder character while it's
                                   // processing, and doing stuff while it's there seems to do bad things
                                   // (like crash).
                                   return [text rangeOfString:@"\uFFFC"].location == NSNotFound;
                               }];
    RAC(self, viewModel.message) = self.message.rac_textSignal;

    [[self.send rac_signalForControlEvents:UIControlEventTouchUpInside]
     subscribeNext:^(id _) {
         @strongify(self);
         [self sendMessage];
     }];

    self.chatLog.dataSource = self;
    self.chatLog.delegate = self;
    
    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard)];
    gestureRecognizer.cancelsTouchesInView = NO;
    [self.chatLog addGestureRecognizer:gestureRecognizer];

    self.cancelSignal = [RACSubject subject];
    [self rac_liftSelector:@selector(repositionForKeyboard:)
               withObjects:[[[RACSignal
                            merge:@[[NSNotificationCenter.defaultCenter
                                     rac_addObserverForName:UIKeyboardWillShowNotification object:nil],
                                    [NSNotificationCenter.defaultCenter
                                     rac_addObserverForName:UIKeyboardWillHideNotification object:nil]]]
                            takeUntil:self.cancelSignal]
                            deliverOn:[RACScheduler mainThreadScheduler]]];
}

- (void)dealloc {
    [self.cancelSignal sendCompleted];
}

- (void)sendMessage {
    [[self.viewModel send]
     subscribeError:^(NSError *error) {
         [WHAlert alertWithMessage:[error description]];
     }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendMessage];
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
    if (showing) height *= -1;
    
    [UIView animateWithDuration:animationDuration animations:^{
        self.messagePanel.frameY += height;
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

- (void)showChatWithJid:(NSString *)jid {
    Contact *newContact = [Contact contactForJid:jid managedObjectContext:[WHCoreData managedObjectContext]];
    if (newContact)
        self.viewModel = [[WHChatViewModel alloc] initWithClient:self.client
                                                         contact:self.contact];
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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    Message *message = self.viewModel.messages[indexPath.row];
    return [WHChatTableViewCell calculateHeight:message];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    Message *message = self.viewModel.messages[indexPath.row];
    NSString *cellIdentifier = [message.incoming boolValue] ? @"IncomingChatCell" : @"OutgoingChatCell";

    WHChatTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    [cell setupWithMessage:message userJid:self.viewModel.jid];
    
    return cell;
}

@end
