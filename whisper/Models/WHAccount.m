//
//  WHAccount.m
//  whisper
//
//  Created by Thomas Goyne on 7/17/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHAccount.h"

#import "WHKeyPair.h"

@import Security;
#import <SSKeychain/SSKeychain.h>

static NSString *serviceName() {
    return [@"com.7x7labs.Whisper." stringByAppendingString:kXmppServerHost];
}

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
    NSArray *accounts = [SSKeychain accountsForService:serviceName()];
    if ([accounts count]) {
        WHAccount *account = [WHAccount new];
        account.jid = accounts[0][kSSKeychainAccountKey];
        account.password = [SSKeychain passwordForService:serviceName() account:account.jid];
        return account;
    }

    // No currently existing account, so generate a new one
    WHAccount *account = [WHAccount new];
    account.jid = [generateRandomString() stringByAppendingFormat:@"@%@", kXmppServerHost];
    account.password = generateRandomString();

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        (void)[WHKeyPair getOwnGlobalKeyPair];
    });

    [SSKeychain setPassword:account.password forService:serviceName() account:account.jid];
    return account;
}

+ (void)delete {
    for (NSDictionary *account in [SSKeychain accountsForService:serviceName()])
        [SSKeychain deletePasswordForService:serviceName() account:account[kSSKeychainAccountKey]];
}
@end
