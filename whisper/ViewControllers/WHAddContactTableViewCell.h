//
//  WHAddContactTableViewCell.h
//  whisper
//
//  Created by Bill Mers on 9/4/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import <UIKit/UIKit.h>

@class WHKeyExchangePeer;

@interface WHAddContactTableViewCell : UITableViewCell

- (void)setupWithPeer:(WHKeyExchangePeer *)peer;

@property (nonatomic) BOOL connecting;

@end
