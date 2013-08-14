//
//  WHAppDelegate.m
//  whisper
//
//  Created by Thomas Goyne on 7/9/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHAppDelegate.h"

#import "WHCoreData.h"

#import "DDLog.h"
#import "DDTTYLogger.h"

@implementation WHAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
#if DEBUG
    if (getenv("runningTests")) {
        self.window.rootViewController = nil;
        return YES;
    }
#endif
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [WHCoreData initSqliteContext];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    __block UIBackgroundTaskIdentifier task = [application beginBackgroundTaskWithExpirationHandler:^{
        [application endBackgroundTask:task];
    }];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    NSError *error;
    if ([[WHCoreData managedObjectContext] hasChanges] && ![[WHCoreData managedObjectContext] save:&error])
        NSLog(@"Error saving pending changes: %@", error);
}
@end
