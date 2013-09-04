//
//  WHAddContactTableViewCell.m
//  whisper
//
//  Created by Bill Mers on 9/4/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHAddContactTableViewCell.h"

#import "Contact.h"
#import "WHKeyExchangePeer.h"

#import <SDWebImage/UIImageView+WebCache.h>

@interface WHAddContactTableViewCell ()
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property (weak, nonatomic) IBOutlet UIButton *addButton;
@property (weak, nonatomic) IBOutlet UIImageView *avatarImage;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;

@property (strong, nonatomic) WHKeyExchangePeer *peer;
@end

@implementation WHAddContactTableViewCell

- (void)setupWithPeer:(WHKeyExchangePeer *)peer {
    self.peer = peer;
    self.nameLabel.text = peer.name;
    
    NSURL *avatarURL = [Contact avatarURLForEmail:peer.peerJid];
    [self.avatarImage setImageWithURL:avatarURL];
}

- (void)setConnecting:(BOOL)connecting {
    _connecting = connecting;

    self.addButton.hidden = connecting;
    self.spinner.hidden = !connecting;
    self.userInteractionEnabled = !connecting;
    
    if (connecting) {
        [self.spinner startAnimating];
    } else {
        [self.spinner stopAnimating];
    }
}

@end
