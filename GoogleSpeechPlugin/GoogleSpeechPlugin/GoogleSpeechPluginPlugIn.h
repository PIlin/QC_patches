//
//  GoogleSpeechPluginPlugIn.h
//  GoogleSpeechPlugin
//
//  Created by Pavel on 10.06.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#import <Quartz/Quartz.h>

@interface GoogleSpeechPluginPlugIn : QCPlugIn

// Declare here the properties to be used as input and output ports for the plug-in e.g.
//@property double inputFoo;
//@property (copy) NSString* outputBar;

@property BOOL inputStartRecord;
@property (copy) NSString* inputLanguage;
@property BOOL inputStrictOrdering;
@property BOOL inputAutomatic;

@property (copy) NSString* outputRecognisedString;
@property double outputRecognitionConfidence;
@property BOOL outputInProcess;

@end
