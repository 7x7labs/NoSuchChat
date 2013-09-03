//
//  main.m
//  whisper
//
//  Created by Thomas Goyne on 7/9/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "WHAppDelegate.h"

static int (*oldStderrWrite)();

static int stderrWrite(void *inFD, const char *buffer, int size) {
    if (strncmp(buffer, "AssertMacros:", 13) == 0)
        return 0;
    return oldStderrWrite(inFD, buffer, size);
}

int main(int argc, char *argv[]) {
    oldStderrWrite = stderr->_write;
    stderr->_write = stderrWrite;
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([WHAppDelegate class]));
    }
}
