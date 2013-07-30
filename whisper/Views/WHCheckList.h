//
//  WHCheckList.h
//  whisper
//
//  Created by Thomas Goyne on 7/30/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

@interface WHCheckList : NSObject
@property (nonatomic, readonly) NSString *value;

- (instancetype)initWithTableView:(UITableView *)tableView
                     initialValue:(NSString *)value
                           labels:(NSArray *)labels
                           values:(NSArray *)values;
@end
