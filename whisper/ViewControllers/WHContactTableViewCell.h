//
//  WHContactTableViewCell.h
//  whisper
//
//  Created by Thomas Goyne on 8/29/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class WHContactRowViewModel;

@interface WHContactTableViewCell : UITableViewCell
- (void)switchToViewModel:(WHContactRowViewModel *)viewModel;
@end
