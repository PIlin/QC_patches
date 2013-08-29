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

#import <sprec/flac_encoder.h>

#import "MemoryStream.h"

#define NUMBER_RECORD_BUFFERS 3


class FlacEncoder;

typedef struct RecorderUserData {
    Boolean                     need_stop;
    Boolean                     running;
    FlacEncoder*                flac_encoder;
} RecorderUserData;


static const uint32_t SAMPLE_RATE = 16000;
static const uint16_t BIT_DEPTH = 16;
static const uint16_t CHANNELS = 1;


static const size_t SAMPLES_IN_BUFFER = SAMPLE_RATE/2;


class FlacEncoder
{
    static int flac_stream_write_callback(struct sprec_flac_encoder_t* encoder, const uint8_t buffer[], size_t bytes, uint32_t samples, uint32_t current_frame, void* user_data)
    {
        FlacEncoder* encWrp = (FlacEncoder*)user_data;
        
        if (bytes != [encWrp->flacStream write:buffer maxLength:bytes])
        {
            return 1;
        }
        
        //NSLog(@"samples %u write to stream %lu", samples, bytes);
        
        return 0;
    }
    
    
    static int flac_stream_seek_callback(struct sprec_flac_encoder_t* encoder, uint64_t offset, void* user_data)
    {
        FlacEncoder* encWrp = (FlacEncoder*)user_data;
        
        [encWrp->flacStream seek:offset];
        
        return 0;
    }
    
    static int flac_stream_tell_callback(struct sprec_flac_encoder_t* encoder, uint64_t* offset, void* user_data)
    {
        FlacEncoder* encWrp = (FlacEncoder*)user_data;
        
        *offset = [encWrp->flacStream tell];
        
        return 0;
    }

    
public:
    FlacEncoder() :
        flacStream(nil),
        flacEncoder(NULL),
        initOk(NO),
        resultReceiver(NULL)
    {
        flacStream = [[MemoryStream alloc] init];
        
        if (!flacStream)
            return;
       
        [flacStream open];
        
        flacEncoder = sprec_flac_create_encoder(SAMPLE_RATE, CHANNELS, BIT_DEPTH);

        if (!flacEncoder)
            return;
        
        
        int res = sprec_flac_bind_encoder_to_stream(flacEncoder,
                                                    flac_stream_write_callback,
                                                    flac_stream_seek_callback /*NULL*/,
                                                    flac_stream_tell_callback /*NULL*/,
                                                    this);

        if (res)
            return;
        
        initOk = YES;
    }
    
    ~FlacEncoder()
    {
        if (initOk)
            sprec_flac_finish_encoder(flacEncoder);
        if (flacEncoder)
            sprec_flac_destroy_encoder(flacEncoder);
            
        if (resultReceiver && flacStream)
        {
            *resultReceiver = [NSData dataWithData:[flacStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey]];
        }
        
        if (flacStream)
            [flacStream close];
    }

    void feed(int32_t* pcm, uint32_t samples)
    {
        if (!initOk)
            return;

        sprec_flac_feed_encoder(flacEncoder, pcm, samples);
    }
    
    void setResultReceiver(NSData* __strong* receiver)
    {
        resultReceiver = receiver;
    }

private:
    MemoryStream* flacStream;
    sprec_flac_encoder_t* flacEncoder;
    BOOL initOk;
    NSData* __strong* resultReceiver;
};


static BOOL vad_found_voice(RecorderUserData const& userData, AudioQueueBufferRef inBuffer)
{
    return YES;
}

static void feed_encoder(RecorderUserData const& userData, AudioQueueBufferRef inBuffer)
{
    static int32_t pcm[CHANNELS * SAMPLES_IN_BUFFER];
    
    uint32_t i = 0;
    for (size_t b = 0; b < inBuffer->mAudioDataByteSize; ++i, b += sizeof(int16_t))
    {
        pcm[i] = *(int16_t*)((char*)inBuffer->mAudioData + b);
    }
    userData.flac_encoder->feed(pcm, i/CHANNELS);
    NSLog(@"sprec_flac_feed_encoder");
}


static void inputBufferHandler(	void* inUserData,
AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, const AudioTimeStamp * inStartTime, UInt32 inNumPackets, const AudioStreamPacketDescription *inPacketDesc)
{
    RecorderUserData& userData = *(RecorderUserData*)inUserData;
    
    try
    {
        NSLog(@"inputBufferHandler buffer = %p", inBuffer);
        
        if (vad_found_voice(userData, inBuffer))
            feed_encoder(userData, inBuffer);
        
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

@property (nonatomic, copy) FinishedFlacDataBlock finishedFlacDataBlock;

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
int computeRecordBufferSize(const AudioStreamBasicDescription *format, AudioQueueRef queue)
{
	int packets, frames, bytes;
	
	frames = SAMPLES_IN_BUFFER;
	
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
        
        _stateCondition = [[NSCondition alloc] init];
        
        memset(&recorderUserData, 0, sizeof(recorderUserData));
    }
    return self;
}

- (void)prepare_flac_encoding
{
    recorderUserData.flac_encoder = new FlacEncoder();
}

- (void)finish_flac_encoding:(BOOL)wasRecordingError
{
    [_stateCondition lock];
    {
        NSData* flacData = nil;
        
        if (!wasRecordingError && recorderUserData.flac_encoder)
            recorderUserData.flac_encoder->setResultReceiver(&flacData);
        
        delete recorderUserData.flac_encoder;
        recorderUserData.flac_encoder = NULL;
        
        if (flacData)
        {
            self.finishedFlacDataBlock(flacData);
        }
    }
    [_stateCondition unlock];
}


- (BOOL)startRecording:(FinishedFlacDataBlock)on_flac_data
{
    self.finishedFlacDataBlock = on_flac_data;
    
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
        
        @autoreleasepool {

            [self prepare_flac_encoding];
            
            BOOL recordingError = [self record];
            
            [self finish_flac_encoding:recordingError];
            
            [_stateCondition lock];
            {
                recorderUserData.running = NO;
                recorderUserData.need_stop = NO;
                
                [_stateCondition broadcast];
            }
            [_stateCondition unlock];

        }
        
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
    
    

    
    BOOL wasError = NO;
    
    AudioStreamBasicDescription recordFormat = initRecordFormatFromPararm(SAMPLE_RATE, CHANNELS, BIT_DEPTH);
    
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
        
        int bufferByteSize = computeRecordBufferSize(&recordFormat, queue);
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


+ (uint32_t)sampleRate
{
    return SAMPLE_RATE;
}

@end
