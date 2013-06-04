//
//  StructFromIterator.m
//  StructFromIterator_Plugin
//
//  Created by Pavel on 30.05.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#import "StructFromIterator.h"

@implementation StructFromIterator

NSUInteger _iterationsCount;
NSUInteger _currentIteration;

QCStructure *outStructure;

// Reallocate structure with enough fields for all iterations
// Old contents will be lost
-(void)allocateStructureForIterations:(NSUInteger)iterationsCount
{
    [self releaseStructure];
    
    if (iterationsCount < 1)
        iterationsCount = 1;
    
    _iterationsCount = iterationsCount;
    _currentIteration = 0;
    
    outStructure = [[QCStructure allocWithZone:NULL] init];
    
    GFList *osl = [outStructure _list];
    
    for (NSUInteger i = 0; i < iterationsCount; ++i)
        [osl insertObject:[NSString string] atIndex:i forKey:nil];
}

-(void)releaseStructure
{
    _iterationsCount = 0;
    _currentIteration = 0;
    [outStructure release];
    outStructure = nil;
}

// Saves the value of inputElement port for current iterations.
// If this function is called _iterationCount times, then it will form a resulting array of iterations.
- (void)performIteration
{
    if ([inputElement wasUpdated] || [inputIterations wasUpdated])
    {
        if ([inputIterations wasUpdated])
        {
            [self allocateStructureForIterations:(NSUInteger)[inputIterations doubleValue]];
        }
        
        id value = [inputElement value];
        if (!value)
        {
            value = [NSString string];
        }
        
        GFList *osl = [outStructure _list];
        [osl setObject:value atIndex:_currentIteration];
        
        _currentIteration = (_currentIteration + 1) % _iterationsCount;
    }
    
    [outputStructure setStructureValue:outStructure];
}


// Boilerplate code to setup patch


+(BOOL)isSafe
{
	return NO;
}

+(BOOL)allowsSubpatchesWithIdentifier:(id)identifier
{
	return NO;
}

+(int)executionModeWithIdentifier:(id)identifier
{
	return kQCPatchExecutionModeProcessor;
}

+(int)timeModeWithIdentifier:(id)identifier
{
	return kQCPatchTimeModeNone;
}

-(id)initWithIdentifier:(id)identifier
{
	if(self = [super initWithIdentifier:identifier])
	{
		[[self userInfo] setObject:@"Structure from Iteration patch (unofficial API)" forKey:@"name"];
	}
	return self;
}

-(BOOL)setup:(QCOpenGLContext*)context
{
    [self allocateStructureForIterations:1];
    
	return YES;
}

-(void)cleanup:(QCOpenGLContext*)context
{
    [self releaseStructure];
}

-(void)enable:(QCOpenGLContext*)context
{
}

-(void)disable:(QCOpenGLContext*)context
{
}



-(BOOL)execute:(QCOpenGLContext*)context time:(double)time arguments:(NSDictionary*)arguments
{
    [self performIteration];
    
	return YES;
}

@end
