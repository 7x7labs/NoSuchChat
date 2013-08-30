//
//  WHContactTableViewCell.m
//  whisper
//
//  Created by Thomas Goyne on 8/29/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHContactTableViewCell.h"

#import "WHContactListViewModel.h"

#import <SDWebImage/UIImageView+WebCache.h>

@interface WHContactTableViewCell ()
@property (nonatomic, strong) WHContactRowViewModel *viewModel;

@property (weak, nonatomic) IBOutlet UIImageView *avatar;
@property (weak, nonatomic) IBOutlet UILabel *name;
@property (weak, nonatomic) IBOutlet UILabel *status;
@end

@implementation WHContactTableViewCell
- (void)switchToViewModel:(WHContactRowViewModel *)viewModel {
    BOOL bind = !self.viewModel;
    self.viewModel = viewModel;

    // Only set up the bindings once since they continue to work as the view
    // model changes
    if (bind) {
        [self.avatar rac_liftSelector:@selector(setImageWithURL:)
                          withObjects:RACAbleWithStart(self, viewModel.gravatarURL)];
        RACBind(self.name, text) = RACBind(self, viewModel.displayName);
        RACBind(self.status, text) = RACBind(self, viewModel.status);
    }
}
@end
