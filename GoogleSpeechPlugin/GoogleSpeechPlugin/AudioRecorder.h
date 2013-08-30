//
//  AudioRecorder.h
//  GoogleSpeechPlugin
//
//  Created by Pavel on 11.06.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#import <Foundation/Foundation.h>

struct VAD;

@interface AudioRecorder : NSObject<NSStreamDelegate>

typedef void (^ FinishedFlacDataBlock)(NSData*);

// Block on_flac_data will be called for each finished flac record
// It will be called from recording thread, so do not block it for too long
- (BOOL)startRecordingWithVAD:(struct VAD*)vad andDataCallback:(FinishedFlacDataBlock)on_flac_data;

- (void)stopRecording;

+ (uint32_t)sampleRate;

@end
