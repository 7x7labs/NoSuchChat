//
//  WHWelcomeViewController.m
//  whisper
//
//  Created by Bill Mers on 8/29/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHWelcomeViewController.h"

#import "WHChatClient.h"
#import "WHWelcomeViewModel.h"

#import <libextobjc/EXTScope.h>

@interface WHWelcomeViewController ()
@property (weak, nonatomic) IBOutlet UITextField *displayName;
@property (weak, nonatomic) IBOutlet UIButton *getStarted;
@property (weak, nonatomic) IBOutlet UIScrollView *scroller;

@property (nonatomic, strong) WHChatClient *client;
@property (nonatomic, strong) WHWelcomeViewModel *viewModel;
@property (nonatomic, strong) NSString *contactJid;
@end

@implementation WHWelcomeViewController
- (void)viewDidLoad {
    RAC(self.getStarted, enabled) = [RACAbleWithStart(self, viewModel.canSave)
                                     map:^id(id value) { return value ?: @NO; }];
    RAC(self, viewModel.displayName) = self.displayName.rac_textSignal;
    RAC(self.displayName, text) = [RACAbleWithStart(self, viewModel.displayName)
                                   filter:^BOOL(NSString *text) {
                                       return [text rangeOfString:@"\uFFFC"].location == NSNotFound;
                                   }];

    @weakify(self)
    [[self.getStarted rac_signalForControlEvents:UIControlEventTouchUpInside]
     subscribeNext:^(id _) {
         @strongify(self);
         [self.viewModel save];
     }];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES];

    self.client = [WHChatClient clientForServer:kXmppServerHost port:5222];
    self.viewModel = [[WHWelcomeViewModel alloc] initWithClient:self.client];

    if (!self.viewModel.isFirstRun)
        [self performSegueWithIdentifier:@"LoadMainNavigation" sender:self];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO];
}

- (void)keyboardWillShow:(NSNotification*)notification {
    NSDictionary* info = [notification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    CGRect rect = self.view.frame;
    rect.size.height -= kbSize.height;
    if (!CGRectContainsPoint(rect, self.getStarted.frame.origin) ) {
        CGPoint scrollPoint = CGPointMake(0.0, self.getStarted.frame.origin.y - kbSize.height);
        [self.scroller setContentOffset:scrollPoint animated:YES];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    id dest = segue.destinationViewController;
    if ([dest respondsToSelector:@selector(setClient:)])
        [dest setClient:self.client];
    if ([dest respondsToSelector:@selector(setContactJid:)])
        [dest setContactJid:self.contactJid];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (self.viewModel.canSave) {
        [self.viewModel save];
        [self performSegueWithIdentifier:@"LoadMainNavigation" sender:self];
    }
    
    return NO;
}

- (void)showChatWithJid:(NSString *)jid {
    self.contactJid = jid;
}
@end
