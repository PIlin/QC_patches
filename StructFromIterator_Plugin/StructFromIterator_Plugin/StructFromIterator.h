//
//  StructFromIterator.h
//  StructFromIterator_Plugin
//
//  Created by Pavel on 30.05.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

@interface StructFromIterator : QCPatch
{
    QCVirtualPort *inputElement;
    QCNumberPort *inputIterations;
    
	QCStructurePort *outputStructure;
}

+(BOOL)isSafe;
+(BOOL)allowsSubpatchesWithIdentifier:(id)identifier;
+(int)executionModeWithIdentifier:(id)identifier;
+(int)timeModeWithIdentifier:(id)identifier;
-(id)initWithIdentifier:(id)identifier;
-(BOOL)setup:(QCOpenGLContext*)context;
-(void)cleanup:(QCOpenGLContext*)context;
-(void)enable:(QCOpenGLContext*)context;
-(void)disable:(QCOpenGLContext*)context;
-(BOOL)execute:(QCOpenGLContext*)context time:(double)time arguments:(NSDictionary*)arguments;

@end
