//
//  WHAlert.m
//  whisper
//
//  Created by Thomas Goyne on 8/2/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHAlert.h"

#import <ReactiveCocoa/ReactiveCocoa.h>

@interface WHAlert ()<UIAlertViewDelegate>
@property (nonatomic, strong) RACSubject *result;
@end

@implementation WHAlert
+ (void)alertWithMessage:(NSString *)message {
     [[[UIAlertView alloc] initWithTitle:nil
                                 message:message
                                delegate:nil
                       cancelButtonTitle:@"OK"
                       otherButtonTitles:nil] show];
}

+ (RACSignal *)alertWithMessage:(NSString *)message buttons:(NSArray *)buttons {
    // ReactiveCocoa 2.0 adds support for UIAlertView, so this dumb code can
    // go away once that's done.
    WHAlert *delegate = [self new];
    delegate.result = [RACSubject new];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                    message:message
                                                   delegate:delegate
                                          cancelButtonTitle:nil
                                          otherButtonTitles:nil];
    for (NSString *button in buttons)
        [alert addButtonWithTitle:button];
    [alert show];
    [delegate.result subscribeCompleted:^{ (void)delegate; }]; // Keep the delegate alive until it completes...
    return delegate.result;
}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    [self.result sendNext:@(buttonIndex)];
    [self.result sendCompleted];
}

@end
