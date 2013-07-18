//
//  NSData+Compression.m
//  whisper
//
//  Created by Thomas Goyne on 7/19/13.
//  Copyright (c) 2013 7x7 Labs. All rights reserved.
//

#import "NSData+Compression.h"

#import <zlib.h>

@implementation NSData (Compression)
- (NSData *)wh_compress {
    if ([self length] == 0) return self;

    z_stream strm = {
        .next_in = (Bytef *)[self bytes],
        .avail_in = [self length]
    };

    if (deflateInit(&strm, Z_BEST_COMPRESSION) != Z_OK) return nil;

    NSMutableData *compressed = [NSMutableData dataWithLength:[self length]];

    do {
        if (strm.total_out >= [compressed length])
            [compressed increaseLengthBy:[compressed length]];

        strm.next_out = [compressed mutableBytes] + strm.total_out;
        strm.avail_out = [compressed length] - strm.total_out;

        deflate(&strm, Z_FINISH);
    } while (strm.avail_out == 0);

    deflateEnd(&strm);

    [compressed setLength:strm.total_out];
    return compressed;
}

- (NSData *)wh_decompress {
    if ([self length] == 0) return self;

    z_stream strm = {
        .next_in = (Bytef *)[self bytes],
        .avail_in = [self length]
    };

    if (inflateInit(&strm) != Z_OK) return nil;

    NSMutableData *decompressed = [NSMutableData dataWithLength:[self length]];

    while (true) {
        if (strm.total_out >= [decompressed length])
            [decompressed increaseLengthBy:[decompressed length]];

        strm.next_out = [decompressed mutableBytes] + strm.total_out;
        strm.avail_out = [decompressed length] - strm.total_out;

        int status = inflate(&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) break;
        if (status != Z_OK) {
            inflateEnd(&strm);
            return nil;
        }
    }

    if (inflateEnd(&strm) != Z_OK) return nil;

    deflateEnd(&strm);

    [decompressed setLength:strm.total_out];
    return decompressed;
}
@end
