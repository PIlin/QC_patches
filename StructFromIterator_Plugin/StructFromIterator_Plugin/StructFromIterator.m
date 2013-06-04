//
//  StructFromIterator.m
//  StructFromIterator_Plugin
//
//  Created by Pavel on 30.05.13.
//  Copyright (c) 2013 Pavel. All rights reserved.
//

#import "StructFromIterator.h"

@implementation StructFromIterator
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
    iterations = 0;
    curIter = 0;
    
    [self allocateStructureForIterations:1];
    
	return YES;
}

-(void)cleanup:(QCOpenGLContext*)context
{
    [self releaseStructure];
}

-(void)allocateStructureForIterations:(NSUInteger)iter
{
    [self releaseStructure];
    
    if (iter < 1)
        iter = 1;
    
    iterations = iter;
    curIter = 0;
    
    outStructure = [[QCStructure allocWithZone:NULL] init];
    
    GFList *osl = [outStructure _list];
    
    for (NSUInteger i = 0; i < iter; ++i)
        [osl insertObject:[NSString string] atIndex:i forKey:nil];
}

-(void)releaseStructure
{
    iterations = 0;
    curIter = 0;
    [outStructure release];
    outStructure = nil;
}

-(void)enable:(QCOpenGLContext*)context
{
}

-(void)disable:(QCOpenGLContext*)context
{
}

-(BOOL)execute:(QCOpenGLContext*)context time:(double)time arguments:(NSDictionary*)arguments
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
        [osl setObject:value atIndex:curIter];
        
        curIter = (curIter + 1) % iterations;
    }
    
    [outputStructure setStructureValue:outStructure];
    
	return YES;
}

@end
