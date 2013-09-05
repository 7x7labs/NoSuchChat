//
//  WHAddContactTableViewCell.h
//  whisper
//
//  Created by Bill Mers on 9/4/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@class WHPotentialContactViewModel;

@interface WHAddContactTableViewCell : UITableViewCell
- (void)setupWithPeer:(WHPotentialContactViewModel *)peer;
- (RACSignal *)connect;
@end
