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


static struct sprec_result *recognize_file(const char *filename, char const* lang, uint32_t samplerate)
{
    int err;
    char* buf;
    int len;
    struct sprec_server_response *resp;
    struct sprec_result *res;
    char *text;
    double confidence;
    
    const char* flacfile = filename;
    
    err = sprec_get_file_contents(flacfile, &buf, &len);
	if (err != 0)
	{
		return NULL;
	}
    
	/**
	 * ...and send it to Google
	 */
	resp = sprec_send_audio_data(buf, len, lang, samplerate);
	free(buf);
	if (resp == NULL)
	{
		return NULL;
	}
    
    
	/**
	 * Get the JSON from the response object,
	 * then parse it to get the actual text and confidence
	 */
	text = sprec_get_text_from_json(resp->data);
	confidence = sprec_get_confidence_from_json(resp->data);
	sprec_free_response(resp);
    
	/**
	 * Compose the return value
	 */
	res = malloc(sizeof(*res));
	if (res == NULL)
	{
		free(text);
		return NULL;
	}
	
	res->text = text;
	res->confidence = confidence;
	return res;
}



#define	kQCPlugIn_Name				@"Google Speech Plugin"
#define	kQCPlugIn_Description		@"Google Speech Plugin allows to use Google Speech-to-Text API."

@interface GoogleSpeechPluginPlugIn ()

@property (strong) NSString* recognisedString;
@property double recognisedConfidence;
@property BOOL recognitionFinished;

@end


@implementation GoogleSpeechPluginPlugIn

// Here you need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation
//@dynamic inputFoo, outputBar;

@dynamic inputStartRecord;
@dynamic inputRecordTime;

@dynamic outputRecognisedString;
@dynamic outputRecognitionConfidence;
@dynamic outputInProcess;




BOOL _prevStartRecordValue;
NSTimeInterval _recordStartedAtTimeInterval;

+ (NSDictionary *)attributes
{
	// Return a dictionary of attributes describing the plug-in (QCPlugInAttributeNameKey, QCPlugInAttributeDescriptionKey...).
    return @{QCPlugInAttributeNameKey:kQCPlugIn_Name, QCPlugInAttributeDescriptionKey:kQCPlugIn_Description};
}

+ (NSDictionary *)attributesForPropertyPortWithKey:(NSString *)key
{
    if ([key isEqualToString:@"inputStartRecord"])
        return @{QCPortAttributeNameKey: @"Start Record",
                 QCPortAttributeDefaultValueKey: @NO};
    if ([key isEqualToString:@"inputRecordTime"])
        return @{QCPortAttributeNameKey: @"Record Time",
                 QCPortAttributeDefaultValueKey: @10.0};
    
    if ([key isEqualToString:@"outputRecognisedString"])
        return @{QCPortAttributeNameKey: @"Recognised String",
                 QCPortAttributeDefaultValueKey: @""};
    if ([key isEqualToString:@"outputRecognitionConfidence"])
        return @{QCPortAttributeNameKey: @"Confidence",
                 QCPortAttributeDefaultValueKey: @0.0};
    if ([key isEqualToString:@"outputInProcess"])
        return @{QCPortAttributeNameKey: @"In process",
                 QCPortAttributeDefaultValueKey: @NO};

//    if ([key isEqualToString:@"inputStartRecord"])
//        return [NSDictionary dictionaryWithObjectsAndKeys:
//                @"Start Record", QCPortAttributeNameKey,
//                NO, QCPortAttributeDefaultValueKey, nil];
//    if ([key isEqualToString:@"inputRecordTime"])
//        return [NSDictionary dictionaryWithObjectsAndKeys:
//                @"Record Time", QCPortAttributeNameKey,
//                @10.0, QCPortAttributeDefaultValueKey, nil];
//
//    if ([key isEqualToString:@"outputRecognisedString"])
//        return [NSDictionary dictionaryWithObjectsAndKeys:
//                @"Recognised String", QCPortAttributeNameKey,
//                @"", QCPortAttributeDefaultValueKey, nil];
//    if ([key isEqualToString:@"outputRecognitionConfidence"])
//        return [NSDictionary dictionaryWithObjectsAndKeys:
//                @"Confidence", QCPortAttributeNameKey,
//                @0.0, QCPortAttributeDefaultValueKey, nil];
//    if ([key isEqualToString:@"outputInProcess"])
//        return [NSDictionary dictionaryWithObjectsAndKeys:
//                @"In process", QCPortAttributeNameKey,
//                NO, QCPortAttributeDefaultValueKey, nil];

    
    
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
    
    BOOL curStartRecordValue = self.inputStartRecord;
    
    if (curStartRecordValue && _prevStartRecordValue != curStartRecordValue)
    {
        double recordTime = self.inputRecordTime;
        
        NSTimeInterval startTime = time;
        
        
        @synchronized(self) {
            
            self.recognitionFinished = NO;
            self.recognisedString = @"";
            self.recognisedConfidence = 0;
            
            self.outputInProcess = YES;
            
            _recordStartedAtTimeInterval = startTime;
            
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            
            NSLog(@"adding task time=%lf", startTime);
            
            dispatch_async(queue, ^{
                NSLog(@"task started for time = %lf",  startTime);
                [self startRecognitionWithTime:recordTime startedAtTime:startTime];
                NSLog(@"task finished for time = %lf",  startTime);
            });
        }
        
        
        
    }
    
    
    @synchronized(self) {
        
        if (self.recognitionFinished)
        {
            self.outputInProcess = NO;
            
            self.outputRecognisedString = [self.recognisedString copy];
            self.outputRecognitionConfidence = self.recognisedConfidence;
            
            self.recognitionFinished = NO;
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

- (void)startRecognitionWithTime:(double)recordTime startedAtTime:(NSTimeInterval)time
{
    
    NSString* resText = nil;
    double resConf = 0;
    
//    [self recognise_file:@"/Users/pavel/voice_records/rp-1.flac"
//              resultText:&resText resultConfidence:&resConf];
    
    [self recogniseFromMicDuration:recordTime
                        resultText:&resText
                  resultConfidence:&resConf];
    
//    resConf = 100;
//    resText = @"asdfasfdsadfsdf";
//    
//    sleep(4);
    
    [self applyRecognition:resText withConfidence:resConf startedAtTime:time];
}

-(void)recognise_file:(NSString*)fileName resultText:(NSString**)resultString resultConfidence:(double*)resultConfidence
{
    struct sprec_result* res = recognize_file([fileName UTF8String], "en-EN", 48000);
    
    NSLog(@"result: %s (%lf)", res->text, res->confidence);
    
    *resultConfidence = res->confidence;
    *resultString = [NSString stringWithUTF8String:res->text];
    
    free(res);
}

-(void) recogniseFromMicDuration:(double)duration resultText:(NSString**)resultString  resultConfidence:(double*)resultConfidence
{
    struct sprec_result* res = sprec_recognize_sync("ru-RU", duration);
    
    *resultConfidence = res->confidence;
    *resultString = [NSString stringWithUTF8String:res->text];
    
    NSLog(@"result: %@ (%lf)", *resultString, *resultConfidence);
    
    sprec_result_free(res);
}

- (void)applyRecognition:(NSString*)text withConfidence:(double)confidence startedAtTime:(NSTimeInterval)time
{
    @synchronized(self) {
        
        if (time != _recordStartedAtTimeInterval)
        {
            NSLog(@"task is outdated. Started at %lf, current started at %lf",
                  time, _recordStartedAtTimeInterval);
            return;
        }
    
        if (!self.recognitionFinished)
        {
            _recognisedString = [text copy];
            _recognisedConfidence = confidence;
            
            self.recognitionFinished = YES;
        }
        
    }
}

@end
