//
//  MemoryStream.m
//  GoogleSpeechPlugin
//
//  Created by Pavel on 13.06.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#import "MemoryStream.h"

@interface MemoryStream ()

@property (strong, nonatomic) NSMutableData* data;
@property off_t currentPosition;

@end


@implementation MemoryStream


- (id)init
{
    self = [super init];
    if (self) {
        self.currentPosition = 0;
        self.delegate = self;
    }
    return self;
}

- (id)initToBuffer:(uint8_t *)buffer capacity:(NSUInteger)capacity
{
    [NSException raise:@"Invalid init method" format:@"initToBuffer:capacity:"];
    return nil;
}

- (id)initToFileAtPath:(NSString *)path append:(BOOL)shouldAppend
{
    [NSException raise:@"Invalid init method" format:@"initToFileAtPath:append:"];
    return nil;
}

- (id)initToMemory
{
    [NSException raise:@"Invalid init method" format:@"initToMemory"];
    return nil;
}

- (id)initWithURL:(NSURL *)url append:(BOOL)shouldAppend
{
    [NSException raise:@"Invalid init method" format:@"initWithURL:append:"];
    return nil;
}


- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len
{

    
    NSLog(@"old cur_pos = %llu, data size = %lu", self.currentPosition, self.data.length);
    
    assert(_data.length >= _currentPosition);
    
    if (_data.length == _currentPosition)
    {
        [_data appendBytes:buffer length:len];
    }
    else
    {
        NSRange range;
        range.location = _currentPosition;
        range.length = len;
        
        NSUInteger rangeEnd = range.location + range.length;
        
        if (rangeEnd > _data.length)
        {
            [_data increaseLengthBy:(_data.length - rangeEnd)];
        }
        
        [_data replaceBytesInRange:range withBytes:buffer length:len];
    }
    
    
    self.currentPosition += len;
    
    NSLog(@"new cur_pos = %llu, data size = %lu", self.currentPosition, self.data.length);
    
    return len;
}

- (BOOL)hasSpaceAvailable
{
    return YES;
}

- (void)seek:(off_t) pos
{
    self.currentPosition = pos;
}

- (off_t)tell
{
    return _currentPosition;
}


-(NSData*) getData
{
    return _data;
}

-(void)setDelegate:(id<NSStreamDelegate>)delegate
{
    if (!delegate)
        _delegate = self;
    else
        _delegate = delegate;
}


- (void)open
{
    self.currentPosition = 0;
    self.data = [[NSMutableData alloc] init];
}

- (void)close
{
    self.data = nil;
    self.currentPosition = 0;
}

- (id)propertyForKey:(NSString *)key
{
    if ([key isEqualToString:NSStreamDataWrittenToMemoryStreamKey])
    {
        return [self getData];
    }
    
    return nil;
}

@end
