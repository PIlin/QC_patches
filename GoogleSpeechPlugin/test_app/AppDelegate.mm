//
//  AppDelegate.m
//  test_app
//
//  Created by Pavel on 13.06.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#import "AppDelegate.h"

#import "AudioRecorder.h"

#import "SimpleVAD.h"

@interface AppDelegate ()

@property (strong) AudioRecorder* recorder;

@end


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    
    
    
    
    _recorder = [[AudioRecorder alloc] init];
    VAD* _vad = new SimpleVAD();
    
    [_recorder startRecordingWithVAD:_vad andDataCallback:^(NSData* flacData) {
        NSLog(@"got ready flac data");
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"got flac data size = %lu", (unsigned long)flacData.length);
            
            static int i = 0;
            NSString* fileName = [NSString stringWithFormat:@"/Users/pavel/code/test_file_%03d.flac", i];
            
            NSOutputStream* stream = [[NSOutputStream alloc] initToFileAtPath:fileName
                                                                       append:NO];
            
            ++i;
            
            [stream open];
            [stream write:(const uint8_t*)flacData.bytes maxLength:flacData.length];
            [stream close];
            
            NSLog(@"file is written: %@", fileName);
        });
    }];
    
    
    double delayInSeconds = 500.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
        [_recorder stopRecording];
        
        delete _vad;
    });
    
    
    NSLog(@"applicationDidFinishLaunching: finished");
}

@end
