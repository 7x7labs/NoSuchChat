//
//  UIImage+Inversion.m
//  whisper
//
//  Created by Bill Mers on 9/8/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "UIImage+Inversion.h"

@implementation UIImage (Inversion)

+ (UIImage *)invert:(UIImage *)image
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
