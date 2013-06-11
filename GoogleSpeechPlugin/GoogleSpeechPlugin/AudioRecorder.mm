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
	AudioQueueRef				queue;
	
	CFAbsoluteTime				queueStartStopTime;
	AudioFileID					recordFile;
	SInt64						recordPacket; // current packet number in record file
	Boolean						running;
	Boolean						verbose;
} RecorderUserData;





static void inputBufferHandler(	void* inUserData,
AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, const AudioTimeStamp * inStartTime, UInt32 inNumPackets, const AudioStreamPacketDescription *inPacketDesc)
{
    RecorderUserData& userData = *(RecorderUserData*)inUserData;
    
    try
    {
        NSLog(@"inputBufferHandler buffer = %p", inBuffer);
        
        // if we're not stopping, re-enqueue the buffe so that it gets filled again
        if (userData.running)
            XThrowIfError(AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL), "AudioQueueEnqueueBuffer failed");
    }
    catch(const CAXException& e)
    {
        char buf[256];
        NSLog(@"inputBufferHandler cathch exception %s (%s)", e.mOperation, e.FormatError(buf));
    }
}



@implementation AudioRecorder


AudioStreamBasicDescription initRecordFormatFromPararm(const uint32_t sample_rate, const uint16_t channels, const uint16_t bit_depth)
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

- (BOOL)record:(UInt32)device
{
    const uint32_t sample_rate = 16000;
    const uint16_t bit_depth = 16;
    const uint16_t channels = 2;
    
    
    NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
							 beforeDate:[NSDate distantFuture]];
    
    
//    AudioDeviceID deviceID = device;
    
    AudioStreamBasicDescription recordFormat = initRecordFormatFromPararm(sample_rate, channels, bit_depth);
    
    RecorderUserData recorderUserData;
    memset(&recorderUserData, 0, sizeof(recorderUserData));
    
    try
    {
        XThrowIfError(AudioQueueNewInput(&recordFormat, inputBufferHandler, &recorderUserData, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode, 0, &recorderUserData.queue), "AudioQueueNewInput failed");
        
        NSLog(@"queue created");
        
        UInt32 size = sizeof(recordFormat);
        XThrowIfError(AudioQueueGetProperty(recorderUserData.queue, kAudioConverterCurrentOutputStreamDescription, &recordFormat, &size), "couldn't get actual queue's format");
        
        int bufferByteSize = computeRecordBufferSize(&recordFormat, recorderUserData.queue, 0.5f);
        for (int i = 0; i < NUMBER_RECORD_BUFFERS;  ++i)
        {
            AudioQueueBufferRef buffer;
            XThrowIfError(AudioQueueAllocateBuffer(recorderUserData.queue, bufferByteSize, &buffer), "AudioQueueAllocateBuffer failed");
            XThrowIfError(AudioQueueEnqueueBuffer(recorderUserData.queue, buffer, 0, NULL), "AudioQueueEnqueueBuffer failed");
        }
        
        
        recorderUserData.running = YES;
        XThrowIfError(AudioQueueStart(recorderUserData.queue, NULL), "AudioQueueStart failed");
        
        //
        //sleep(4);
        
        RecorderUserData* pud = &recorderUserData;
        double delayInSeconds = 4.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_current_queue(), ^(void){
            
            NSLog(@"4 seconds passed, stop recording");
            pud->running = NO;
            
        });
        
        
        while( recorderUserData.running )
        {
            //NSLog(@"before CFRunLoopRunInMode");
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, FALSE);
            //NSLog(@"after CFRunLoopRunInMode");
        }
        
        
        XThrowIfError(AudioQueueStop(recorderUserData.queue, TRUE), "AudioQueueStop failed");
        
    cleanup:
        
        AudioQueueDispose(recorderUserData.queue, YES);
    }
    catch(const CAXException& e)
    {
        // ????
        AudioQueueDispose(recorderUserData.queue, YES);
        
        char buf[256];
        NSLog(@"cathch exception %s (%s)", e.mOperation, e.FormatError(buf));
        
        return YES;
    }
    
   
    
    return NO;
}


@end
