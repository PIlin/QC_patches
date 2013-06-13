//
//  MemoryStream.h
//  GoogleSpeechPlugin
//
//  Created by Pavel on 13.06.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#import <Foundation/Foundation.h>


// Use NSStreamDataWrittenToMemoryStreamKey to get data
@interface MemoryStream : NSOutputStream<NSStreamDelegate>

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len;
- (BOOL)hasSpaceAvailable;

- (void)seek:(off_t) pos;
- (off_t)tell;

//-(void)setDelegate:(id<NSStreamDelegate>)delegate;


@property (weak, nonatomic) id<NSStreamDelegate> delegate;

@end
