//
//  WHAvatar.m
//  whisper
//
//  Created by Bill Mers on 9/11/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "WHAvatar.h"

#import "IGIdenticon.h"

@implementation WHAvatar

+ (NSMutableDictionary *)cache
{
    static dispatch_once_t once;
    static NSMutableDictionary* dict;
    dispatch_once(&once, ^{
        dict = [[NSMutableDictionary alloc] init];
    });

    return dict;
}

// generate identicon and invert with CIColorInvert to get lighter colors
+ (UIImage *)avatarForEmail:(NSString *)email
{
    if ([self cache][email])
        return [self cache][email];
    
    UIImage *identicon;
    identicon = [IGIdenticon identiconWithString:email size:68 backgroundColor:[UIColor whiteColor]];
    identicon = [self invertImage:identicon];

    [self cache][email] = identicon;
    
    return identicon;
}

+ (UIImage *)invertImage:(UIImage *)image
{
    CIImage *input = [[CIImage alloc] initWithImage:image];
    CIFilter *filter = [CIFilter filterWithName:@"CIColorInvert"];
    
    [filter setDefaults];
    [filter setValue:input forKey:kCIInputImageKey];
    
    CIImage *output = [filter outputImage];
    CIContext *context = [CIContext contextWithOptions:nil];
    
    CGImageRef cg = [context createCGImage:output fromRect:[output extent]];
    UIImage *returnImage = [UIImage imageWithCGImage:cg];
    CGImageRelease(cg);
    
    return returnImage;
}

@end
