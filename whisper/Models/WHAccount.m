//
//  WHAccount.m
//  whisper
//
//  Created by Thomas Goyne on 7/17/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHAccount.h"

#import <Security/Security.h>
#import <SSKeychain/SSKeychain.h>

static NSString *kServiceName = @"com.7x7labs.Whisper";

@interface WHAccount ()
@property (nonatomic, strong) NSString *jid;
@property (nonatomic, strong) NSString *password;
@end

static NSString *generateRandomString() {
    uint8_t buff[20];
    SecRandomCopyBytes(NULL, 20, buff);
    NSMutableString *string = [NSMutableString stringWithCapacity:(40)];
    for (size_t i = 0; i < 20; ++i)
        [string appendFormat:@"%02x", buff[i]];
    return string;
}

@implementation WHAccount
+ (WHAccount *)get {
    NSArray *accounts = [SSKeychain accountsForService:kServiceName];
    if ([accounts count]) {
        WHAccount *account = [WHAccount new];
        account.jid = accounts[0][kSSKeychainAccountKey];
        account.password = [SSKeychain passwordForService:kServiceName account:account.jid];
        return account;
    }

    // No currently existing account, so generate a new one
    WHAccount *account = [WHAccount new];
    account.jid = [generateRandomString() stringByAppendingFormat:@"@%@", kXmppServerHost];
    account.password = generateRandomString();

    [SSKeychain setPassword:account.password forService:kServiceName account:account.jid];
    return account;
}

@end
