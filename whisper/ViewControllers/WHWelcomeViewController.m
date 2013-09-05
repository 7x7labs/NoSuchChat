//
//  WHWelcomeViewController.m
//  whisper
//
//  Created by Bill Mers on 8/29/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHWelcomeViewController.h"

#import "WHChatClient.h"
#import "WHSettingsViewModel.h"

@interface WHWelcomeViewController ()
@property (weak, nonatomic) IBOutlet UITextField *displayName;
@property (weak, nonatomic) IBOutlet UIButton *getStarted;

@property (nonatomic, strong) WHChatClient *client;
@property (nonatomic, strong) WHSettingsViewModel *viewModel;
@property (nonatomic, strong) NSString *contactJid;
@end

@implementation WHWelcomeViewController
- (void)viewDidLoad {
    [super viewDidLoad];

    self.client = [WHChatClient clientForServer:kXmppServerHost port:5222];
    self.viewModel = [[WHSettingsViewModel alloc] initWithClient:self.client];
    
    // TODO: Add `isFirstRun` bool to NSUserDefaults
    if (![self.client.displayName isEqualToString:@"User Name"]) {
        [self performSegueWithIdentifier:@"LoadMainNavigation" sender:self];
    }
    
    // TODO: Create a ViewModel for this
    RAC(self.getStarted, enabled) = RACAbleWithStart(self.client, connected);

    RAC(self.displayName, text) = [RACAbleWithStart(self.viewModel, displayName)
                                   filter:^BOOL(NSString *text) {
                                       return [text rangeOfString:@"\uFFFC"].location == NSNotFound;
                                   }];
    RAC(self.viewModel.displayName) = self.displayName.rac_textSignal;

    // TODO: Respect viewModel.valid
    [[self.getStarted rac_signalForControlEvents:UIControlEventTouchUpInside]
     subscribeNext:^(id _) {
         [self.viewModel save];
     }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    id dest = segue.destinationViewController;
    if ([dest respondsToSelector:@selector(setClient:)])
        [dest setClient:self.client];
    if ([dest respondsToSelector:@selector(setContactJid:)])
        [dest setContactJid:self.contactJid];
}

- (IBAction)textFieldDidEndOnExit:(UITextField *)sender {}

- (void)showChatWithJid:(NSString *)jid {
    self.contactJid = jid;
}
@end
