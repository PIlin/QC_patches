//
//  AudioRecorder.h
//  GoogleSpeechPlugin
//
//  Created by Pavel on 11.06.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioRecorder : NSObject<NSStreamDelegate>


- (BOOL)startRecording;

- (NSData*)stopRecording;

@end
