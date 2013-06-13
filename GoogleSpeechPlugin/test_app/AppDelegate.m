//
//  AppDelegate.m
//  test_app
//
//  Created by Pavel on 13.06.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#import "AppDelegate.h"

#import "AudioRecorder.h"

@interface AppDelegate ()

@property (strong) AudioRecorder* recorder;

@end


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    
    
    
    
    _recorder = [[AudioRecorder alloc] init];
    
    [_recorder startRecording];
    
    
    double delayInSeconds = 5.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
        NSData* flacData = [_recorder stopRecording];
        
        NSLog(@"got flac data size = %lu", (unsigned long)flacData.length);
        
        NSOutputStream* stream = [[NSOutputStream alloc] initToFileAtPath:@"/Users/pavel/code/test_file.flac" append:NO];
        
        [stream open];
        [stream write:flacData.bytes maxLength:flacData.length];
        [stream close];
    });
    
    
    
}

@end
