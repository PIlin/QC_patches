//
//  AudioRecorder.m
//  GoogleSpeechPlugin
//
//  Created by Pavel on 11.06.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#import "AudioRecorder.h"

#import <AudioToolbox/AudioToolbox.h>

#import "CAXException.h"

#define NUMBER_RECORD_BUFFERS 3


typedef struct RecorderUserData {
    Boolean                     need_stop;
    Boolean                     running;
} RecorderUserData;





static void inputBufferHandler(	void* inUserData,
AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, const AudioTimeStamp * inStartTime, UInt32 inNumPackets, const AudioStreamPacketDescription *inPacketDesc)
{
    RecorderUserData& userData = *(RecorderUserData*)inUserData;
    
    try
    {
        NSLog(@"inputBufferHandler buffer = %p", inBuffer);
        
        // if we're not stopping, re-enqueue the buffe so that it gets filled again
        // TODO: unprotected access to cond var. It's only bool so it's should be ok. And we flush all the buffers after the need_stop is set to the YES.
        if (!userData.need_stop)
            XThrowIfError(AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL), "AudioQueueEnqueueBuffer failed");
    }
    catch(const CAXException& e)
    {
        char buf[256];
        NSLog(@"inputBufferHandler cathch exception %s (%s)", e.mOperation, e.FormatError(buf));
    }
}


@interface AudioRecorder ()

@property (strong) NSCondition* stateCondition;

@end

@implementation AudioRecorder

// Protect access with stateCondition.
RecorderUserData recorderUserData;

static AudioStreamBasicDescription initRecordFormatFromPararm(const uint32_t sample_rate, const uint16_t channels, const uint16_t bit_depth)
{
    AudioStreamBasicDescription recordFormat;
    memset(&recordFormat, 0, sizeof(recordFormat));
    
    recordFormat.mFormatID = kAudioFormatLinearPCM;
	recordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
	recordFormat.mReserved = 0;
	recordFormat.mSampleRate = sample_rate;
	recordFormat.mChannelsPerFrame = channels;
	recordFormat.mBitsPerChannel = bit_depth;
	recordFormat.mBytesPerFrame = channels * bit_depth / 8;
	recordFormat.mFramesPerPacket = 1;
	recordFormat.mBytesPerPacket = recordFormat.mFramesPerPacket * recordFormat.mBytesPerFrame;
    return recordFormat;
}

// ____________________________________________________________________________________
// Determine the size, in bytes, of a buffer necessary to represent the supplied number
// of seconds of audio data.
int computeRecordBufferSize(const AudioStreamBasicDescription *format, AudioQueueRef queue, float seconds)
{
	int packets, frames, bytes;
	
	frames = (int)ceil(seconds * format->mSampleRate);
	
	if (format->mBytesPerFrame > 0)
		bytes = frames * format->mBytesPerFrame;
	else {
		UInt32 maxPacketSize;
		if (format->mBytesPerPacket > 0)
			maxPacketSize = format->mBytesPerPacket;	// constant packet size
		else {
			UInt32 propertySize = sizeof(maxPacketSize);
			XThrowIfError(AudioQueueGetProperty(queue, kAudioConverterPropertyMaximumOutputPacketSize, &maxPacketSize,
												&propertySize), "couldn't get queue's maximum output packet size");
		}
		if (format->mFramesPerPacket > 0)
			packets = frames / format->mFramesPerPacket;
		else
			packets = frames;	// worst-case scenario: 1 frame in a packet
		if (packets == 0)		// sanity check
			packets = 1;
		bytes = packets * maxPacketSize;
	}
	return bytes;
}



- (id)init
{
    self = [super init];
    if (self) {
        memset(&recorderUserData, 0, sizeof(recorderUserData));
    }
    return self;
}


- (BOOL)startRecording
{
    BOOL wasError = NO;
    [_stateCondition lock];
    {
        if (recorderUserData.running)
        {
            NSLog(@"already recording");
            wasError = YES;
        }
        else
        {
            memset(&recorderUserData, 0, sizeof(recorderUserData));
            recorderUserData.running = YES;
        }
    }
    [_stateCondition unlock];
    
    if (wasError)
    {
        return wasError;
    }
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_async(queue, ^{
        NSLog(@"started recording");
        
        [self record];
        
        [_stateCondition lock];
        
        recorderUserData.running = NO;
        recorderUserData.need_stop = NO;
        [_stateCondition broadcast];
        
        [_stateCondition unlock];
        
        NSLog(@"recording finished");
    });
    
    return wasError;
}

- (void)stopRecording
{
    NSLog(@"asking for recording to stop");
    
    [_stateCondition lock];
    if (recorderUserData.running)
    {
        recorderUserData.need_stop = YES;
        
        while (recorderUserData.need_stop)
            [_stateCondition wait];
    }
    [_stateCondition unlock];
    
    NSLog(@"recording stopped");
}



- (BOOL)record
{
    NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
    [runLoop runMode:NSDefaultRunLoopMode
							 beforeDate:[NSDate distantFuture]];
    
    
    const uint32_t sample_rate = 16000;
    const uint16_t bit_depth = 16;
    const uint16_t channels = 2;
    
    BOOL wasError = NO;
    
    AudioStreamBasicDescription recordFormat = initRecordFormatFromPararm(sample_rate, channels, bit_depth);
    
    AudioQueueRef queue;
    
    try
    {
        XThrowIfError(AudioQueueNewInput(&recordFormat, inputBufferHandler, &recorderUserData, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode, 0, &queue), "AudioQueueNewInput failed");
        
        NSLog(@"queue created");
        
        UInt32 size = sizeof(recordFormat);
        XThrowIfError(AudioQueueGetProperty(queue, kAudioConverterCurrentOutputStreamDescription, &recordFormat, &size), "couldn't get actual queue's format");
        
        if (!(recordFormat.mFormatFlags & (kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked)))
        {
            XThrow(1, "returned recordFormat is not supported");
        }
        
        int bufferByteSize = computeRecordBufferSize(&recordFormat, queue, 0.5f);
        for (int i = 0; i < NUMBER_RECORD_BUFFERS;  ++i)
        {
            AudioQueueBufferRef buffer;
            XThrowIfError(AudioQueueAllocateBuffer(queue, bufferByteSize, &buffer), "AudioQueueAllocateBuffer failed");
            XThrowIfError(AudioQueueEnqueueBuffer(queue, buffer, 0, NULL), "AudioQueueEnqueueBuffer failed");
        }
        
        
        XThrowIfError(AudioQueueStart(queue, NULL), "AudioQueueStart failed");
       
        
        while (TRUE)
        {
            BOOL stop = NO;
            [_stateCondition lock];
            stop = recorderUserData.need_stop;
            [_stateCondition unlock];
            
            if (stop)
                break;
            
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, FALSE);
        }

        XThrowIfError(AudioQueueStop(queue, TRUE), "AudioQueueStop failed");
 
    }
    catch(const CAXException& e)
    {
        char buf[256];
        NSLog(@"cathch exception %s (%s)", e.mOperation, e.FormatError(buf));
        
        wasError = YES;
    }
    
    AudioQueueDispose(queue, YES);
    queue = nil;
    
    return wasError;
}


@end
