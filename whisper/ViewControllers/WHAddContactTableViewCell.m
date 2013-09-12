//
//  WHAddContactTableViewCell.m
//  whisper
//
//  Created by Bill Mers on 9/4/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHAddContactTableViewCell.h"

#import "WHAddContactViewModel.h"

#import <libextobjc/EXTScope.h>

@interface WHAddContactTableViewCell ()
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property (weak, nonatomic) IBOutlet UIButton *addButton;
@property (weak, nonatomic) IBOutlet UIImageView *avatarImage;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;

@property (strong, nonatomic) WHPotentialContactViewModel *viewModel;
@end

@implementation WHAddContactTableViewCell

- (void)setupWithPeer:(WHPotentialContactViewModel *)viewModel {
    if (!self.viewModel) {

        RAC(self.addButton, hidden)       = RACAble(self, viewModel.connecting);
        RAC(self.avatarImage, image)      = RACAble(self, viewModel.avatar);
        RAC(self.nameLabel, text)         = RACAble(self, viewModel.name);
        RAC(self.spinner, hidden)         = [RACAble(self, viewModel.connecting) not];
        RAC(self, userInteractionEnabled) = [RACAble(self, viewModel.connecting) not];
        
        @weakify(self);
        [RACAble(self, viewModel.connecting) subscribeNext:^(NSNumber *value) {
            @strongify(self);
            if ([value boolValue])
                [self.spinner startAnimating];
            else
                [self.spinner stopAnimating];
        }];
    }

    self.viewModel = viewModel;
}

- (RACSignal *)connect {
    return [self.viewModel connect];
}

@end
