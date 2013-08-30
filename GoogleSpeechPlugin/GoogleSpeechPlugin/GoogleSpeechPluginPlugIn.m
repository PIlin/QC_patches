//
//  GoogleSpeechPluginPlugIn.m
//  GoogleSpeechPlugin
//
//  Created by Pavel on 10.06.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

// It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering
#import <OpenGL/CGLMacro.h>

#import "GoogleSpeechPluginPlugIn.h"

#import <sprec/sprec.h>

#import "AudioRecorder.h"

#import "VAD/VAD_factory.h"

#define	kQCPlugIn_Name				@"Google Speech Plugin"
const char* description = "Google Speech Plugin allows to use Google Speech-to-Text API.\n"
"\n"
"Set input language in format en-US, ru-RU, de-DE, ...\n"
"Strict ordering option will preserve the order of the queries. If enabled, only last query result will be shown. If disabled, last query result can be replaced by previous, if previous query took more time to process.\n"
;

@interface GoogleSpeechPluginPlugIn ()

@property (strong) NSString* recognisedString;
@property double recognisedConfidence;
@property BOOL recognitionFinished;
@property BOOL strictOrdering;


@property (strong) AudioRecorder* recorder;

@property (strong) NSCondition* stopCondition;
@property BOOL needStop;
@property (atomic) BOOL recordingTaskInProcess;
@property (atomic) BOOL prevRecordingTaskInProcess;
@property (atomic) NSUInteger netQueries;
@property (atomic) NSUInteger prevNetQueries;
@end


@implementation GoogleSpeechPluginPlugIn

// Here you need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation
//@dynamic inputFoo, outputBar;

@dynamic inputStartRecord;
@dynamic inputLanguage;
@dynamic inputStrictOrdering;
@dynamic inputAutomatic;
@dynamic inputAutomaticLevelThreshold;

@dynamic outputRecognisedString;
@dynamic outputRecognitionConfidence;
@dynamic outputInProcess;
@dynamic outputNetworkQueriesInProcess;


BOOL _prevAutomaticValue;
BOOL _prevStartRecordValue;
NSTimeInterval _recordStartedAtTimeInterval;

+ (NSDictionary *)attributes
{
	// Return a dictionary of attributes describing the plug-in (QCPlugInAttributeNameKey, QCPlugInAttributeDescriptionKey...).
    return @{QCPlugInAttributeNameKey:kQCPlugIn_Name, QCPlugInAttributeDescriptionKey:@(description)};
}

+ (NSDictionary *)attributesForPropertyPortWithKey:(NSString *)key
{
    if ([key isEqualToString:@"inputStartRecord"])
        return @{QCPortAttributeNameKey: @"Start Record",
                 QCPortAttributeDefaultValueKey: @NO};
    if ([key isEqualToString:@"inputLanguage"])
        return @{QCPortAttributeNameKey: @"Langugae",
                 QCPortAttributeDefaultValueKey: @"ru-RU"};
    if ([key isEqualToString:@"inputStrictOrdering"])
        return @{QCPortAttributeNameKey: @"Strict ordering",
                 QCPortAttributeDefaultValueKey: @YES};
    if ([key isEqualToString:@"inputAutomatic"])
        return @{QCPortAttributeNameKey: @"Automatic",
                 QCPortAttributeDefaultValueKey: @NO};
    if ([key isEqualToString:@"inputAutomaticLevelThreshold"])
        return @{QCPortAttributeNameKey: @"Level threshold",
                 QCPortAttributeDefaultValueKey: @100.0};
    
    if ([key isEqualToString:@"outputRecognisedString"])
        return @{QCPortAttributeNameKey: @"Recognised String",
                 QCPortAttributeDefaultValueKey: @""};
    if ([key isEqualToString:@"outputRecognitionConfidence"])
        return @{QCPortAttributeNameKey: @"Confidence",
                 QCPortAttributeDefaultValueKey: @0.0};
    if ([key isEqualToString:@"outputInProcess"])
        return @{QCPortAttributeNameKey: @"In process",
                 QCPortAttributeDefaultValueKey: @NO};
    if ([key isEqualToString:@"outputNetworkQueriesInProcess"])
        return @{QCPortAttributeNameKey: @"Net queries",
                 QCPortAttributeDefaultValueKey: @0.0};

	return nil;
}

+ (QCPlugInExecutionMode)executionMode
{
	// Return the execution mode of the plug-in: kQCPlugInExecutionModeProvider, kQCPlugInExecutionModeProcessor, or kQCPlugInExecutionModeConsumer.
	return kQCPlugInExecutionModeProvider;
}


+ (QCPlugInTimeMode)timeMode
{
	// Return the time dependency mode of the plug-in: kQCPlugInTimeModeNone, kQCPlugInTimeModeIdle or kQCPlugInTimeModeTimeBase.
	return kQCPlugInTimeModeIdle;
}

- (id)init
{
	self = [super init];
	if (self) {

        _recognisedString = @"";
        _recognisedConfidence = 0;
        _recognitionFinished = NO;
        
        _stopCondition = [[NSCondition alloc] init];
        _needStop = NO;
        
        
        _recorder = [[AudioRecorder alloc] init];
        
        _prevAutomaticValue = NO;
        
        self.recordingTaskInProcess = NO;
        self.prevRecordingTaskInProcess = NO;
        self.netQueries = 0;
	}
	
	return self;
}


@end

@implementation GoogleSpeechPluginPlugIn (Execution)

- (BOOL)startExecution:(id <QCPlugInContext>)context
{
	// Called by Quartz Composer when rendering of the composition starts: perform any required setup for the plug-in.
	// Return NO in case of fatal failure (this will prevent rendering of the composition to start).
	
	return YES;
}

- (void)enableExecution:(id <QCPlugInContext>)context
{
	// Called by Quartz Composer when the plug-in instance starts being used by Quartz Composer.
    
    NSLog(@"enableExecution");
}

- (BOOL)execute:(id <QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary *)arguments
{
	/*
	Called by Quartz Composer whenever the plug-in instance needs to execute.
	Only read from the plug-in inputs and produce a result (by writing to the plug-in outputs or rendering to the destination OpenGL context) within that method and nowhere else.
	Return NO in case of failure during the execution (this will prevent rendering of the current frame to complete).
	
	The OpenGL context for rendering can be accessed and defined for CGL macros using:
	CGLContextObj cgl_ctx = [context CGLContextObj];
	*/
    
    BOOL curAutomaticValue = self.inputAutomatic;
    
    if (_prevAutomaticValue != curAutomaticValue)
    {
        _prevAutomaticValue = curAutomaticValue;
        if (curAutomaticValue)
        {
            [self startRecognition:self.inputLanguage atTime:time automatic:YES levelThreshold:self.inputAutomaticLevelThreshold];
        }
        else
        {
            [self stopRecognition];
        }
        
    }
    
    
    
    
    
    BOOL curStartRecordValue = self.inputStartRecord;
    
    if (!curAutomaticValue && _prevStartRecordValue != curStartRecordValue)
    {
        if (curStartRecordValue)
        {
            // rising edge
            // start recording
            
            NSTimeInterval startTime = time;
            
            
            @synchronized(self) {

                self.recognitionFinished = NO;
                self.recognisedString = @"";
                self.recognisedConfidence = 0;
                
                
                
                _recordStartedAtTimeInterval = startTime;

                [self.stopCondition lock];
                self.needStop = NO;
                [self.stopCondition unlock];

                [self startRecognition:self.inputLanguage atTime:startTime automatic:NO];

            }
        }
        else
        {
            // falling edge
            // stop recording
            
            [self stopRecognition];
        }

    }
    
    
    @synchronized(self) {

        self.strictOrdering = self.inputStrictOrdering;
        
        if (self.recognitionFinished)
        {
            self.outputRecognisedString = [self.recognisedString copy];
            self.outputRecognitionConfidence = self.recognisedConfidence;
            
            self.recognitionFinished = NO;
        }
        
        if (self.recordingTaskInProcess != self.prevRecordingTaskInProcess)
        {
            self.outputInProcess = self.recordingTaskInProcess;
            self.prevRecordingTaskInProcess = self.recordingTaskInProcess;
        }
        
        if (self.netQueries != self.prevNetQueries)
        {
            self.prevNetQueries = self.netQueries;
            self.outputNetworkQueriesInProcess = (double)self.netQueries;
        }
    }
    
    _prevStartRecordValue = curStartRecordValue;
    
	return YES;
}

- (void)disableExecution:(id <QCPlugInContext>)context
{
	// Called by Quartz Composer when the plug-in instance stops being used by Quartz Composer.
    
    NSLog(@"disableExecution");
}

- (void)stopExecution:(id <QCPlugInContext>)context
{
	// Called by Quartz Composer when rendering of the composition stops: perform any required cleanup for the plug-in.
    
    NSLog(@"stopExecution");
}


#pragma mark Recognition implementation


- (void)startRecognition:(NSString*)language atTime:(NSTimeInterval)atTime automatic:(BOOL)automatic levelThreshold:(double)levelThreshold
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        NSLog(@"started recoginition task for time %lf", atTime);
        self.recordingTaskInProcess = YES;

        
        struct VAD* vad = NULL;
        if (automatic)
            vad = getSimpleVAD(levelThreshold);
        
        [_recorder startRecordingWithVAD:vad andDataCallback:^(NSData* flacData) {
            dispatch_queue_t rq = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
            dispatch_async(rq, ^{
                NSLog(@"got flac data size = %lu", (unsigned long)flacData.length);
                
                
                NSString* text = nil;
                double confidence = 0;
                
                ++self.netQueries;
                {
                    struct sprec_result* res = sprec_recognize_audio_sync(flacData.bytes, flacData.length, [AudioRecorder sampleRate], [language cStringUsingEncoding:NSUTF8StringEncoding]);
                    
                    if (res && res->text)
                    {
                        assert(res->text);
                        text = [NSString stringWithUTF8String:res->text];
                        confidence = res->confidence;
                        
                        NSLog(@"result: %@ (%lf)", text, res->confidence);
                    }
                    else
                    {
                        NSLog(@"error recognizing audio");
                    }
                    
                    sprec_result_free(res);
                }
                --self.netQueries;
                
                @synchronized(self) {
                    
                    if (!self.recognitionFinished)
                    {
                        if (automatic || !self.strictOrdering || _recordStartedAtTimeInterval == atTime)
                        {
                            self.recognisedString = text;
                            self.recognisedConfidence = confidence;
                            
                            self.recognitionFinished = YES;
                        }
                    }
                    
                }

            });
        }];
        
        [self.stopCondition lock];
        while (!self.needStop)
            [self.stopCondition wait];
        
        self.needStop = NO;
        [self.stopCondition unlock];
        
        
        [_recorder stopRecording];

        if (automatic)
            destroyVAD(vad);

        self.recordingTaskInProcess = NO;
        NSLog(@"finished recoginition task for time %lf", atTime);
    });
}

- (void)stopRecognition
{
    NSLog(@"stopRecognition");
    [self.stopCondition lock];
    self.needStop = YES;
    [self.stopCondition broadcast];
    [self.stopCondition unlock];
    NSLog(@"stopRecognition done");
}


@end
