//
//  WHAppDelegate.m
//  whisper
//
//  Created by Thomas Goyne on 7/9/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHAppDelegate.h"

#import "Contact.h"
#import "Message.h"
#import "WHCoreData.h"
#import "WHWelcomeViewController.h"

#import "DDLog.h"
#import "DDTTYLogger.h"
#import "TestFlight.h"

@interface WHAppDelegate ()
@property (nonatomic, strong) void (^completionHandler)(UIBackgroundFetchResult);
@end

@implementation WHAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
#if DEBUG
    if (getenv("runningTests")) {
        self.window.rootViewController = nil;
        return YES;
    }
#endif

    [TestFlight takeOff:@"7aaf3986-4173-443b-8474-ff3df504d034"];
    
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [WHCoreData initSqliteContext];
    [Message deleteOlderThan:[NSDate dateWithTimeIntervalSinceNow:-(60 * 60 * 24 * 7)]];
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];

    id notification;
    if ((notification = launchOptions[UIApplicationLaunchOptionsLocalNotificationKey]))
        [self application:application didReceiveLocalNotification:notification];
    else if ((notification = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey])) {
        NSString *jid = notification[@"jid"];
        NSAssert(jid, @"Remote notification should have contact jid");

        id activeViewController = [(UINavigationController *)self.window.rootViewController topViewController];
        NSAssert([activeViewController respondsToSelector:@selector(showChatWithJid:)],
                 @"All view controllers must implement showChatWithJid:");

        if ([activeViewController respondsToSelector:@selector(showChatWithJid:)])
            [(id)activeViewController showChatWithJid:jid];
    }

    [application registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
}

- (void)application:(UIApplication *)application
didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSLog(@"Got device token: %@", deviceToken);
    self.deviceToken = deviceToken;
}

- (void)application:(UIApplication *)application
didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    NSLog(@"Error registering for push notifications: %@", error);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    // Normally shouldn't be called, since it means we're running, connected to
    // the internet and the server is up, but we're not connected to the server,
    // but it could happen if our connection is temporarily interrupted (or
    // just due to a bug).
    // Remote notifications while we're running don't display a banner, so turn
    // it into a local notification.
    Contact *contact = [Contact contactForJid:userInfo[@"jid"]
                         managedObjectContext:[WHCoreData managedObjectContext]];
    if (!contact) return;

    UILocalNotification *localNotification = [UILocalNotification new];
    localNotification.alertBody = [NSString stringWithFormat:@"New message from %@", contact.name];;
    localNotification.userInfo = @{@"jid": contact.jid};
    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
}

- (void)application:(UIApplication *)application
didReceiveLocalNotification:(UILocalNotification *)notification
{
    if (!notification) return;

    NSString *jid = notification.userInfo[@"jid"];
    NSAssert(jid, @"Local notification should have contact jid");

    id activeViewController = [(UINavigationController *)self.window.rootViewController topViewController];
    NSAssert([activeViewController respondsToSelector:@selector(showChatWithJid:)],
             @"All view controllers must implement showChatWithJid:");

    if ([activeViewController respondsToSelector:@selector(showChatWithJid:)])
        [(id)activeViewController showChatWithJid:jid];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    __block UIBackgroundTaskIdentifier task = [application beginBackgroundTaskWithExpirationHandler:^{
        [application endBackgroundTask:task];
    }];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
}

- (void)applicationWillTerminate:(UIApplication *)application {
    NSError *error;
    if ([[WHCoreData managedObjectContext] hasChanges] && ![[WHCoreData managedObjectContext] save:&error])
        NSLog(@"Error saving pending changes: %@", error);
}

- (void)application:(UIApplication *)application
performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler
{
    self.completionHandler = completionHandler;
}

- (void)backgroundFetchComplete {
    if (self.completionHandler) {
        self.completionHandler(UIBackgroundFetchResultNewData);
        self.completionHandler = nil;
    }
}
@end
