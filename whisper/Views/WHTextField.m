//
//  WHTextField.m
//  whisper
//
//  Created by Bill Mers on 9/7/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHTextField.h"

#import <UIKit/UIKit.h>

@implementation WHTextField

- (id)initWithCoder:(NSCoder *)decoder
{
    if (self = [super initWithCoder:decoder]) {
        [self applyBorderStyle];
    }
    return self;
}

- (void)applyBorderStyle
{
    self.layer.cornerRadius = 5.0f;
    self.layer.masksToBounds = YES;
    self.layer.borderColor = [[UIColor colorWithRed:80/255.0 green:80/255.0 blue:80/255.0 alpha:1.0] CGColor];
    self.layer.borderWidth = 1.0f;
}

@end
