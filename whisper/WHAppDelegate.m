//
//  WHAppDelegate.m
//  whisper
//
//  Created by Thomas Goyne on 7/9/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHAppDelegate.h"

#import "Message.h"
#import "WHCoreData.h"

#import "DDLog.h"
#import "DDTTYLogger.h"

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
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [WHCoreData initSqliteContext];
    [Message deleteOlderThan:[NSDate dateWithTimeIntervalSinceNow:-(60 * 60 * 24 * 7)]];
    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
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
