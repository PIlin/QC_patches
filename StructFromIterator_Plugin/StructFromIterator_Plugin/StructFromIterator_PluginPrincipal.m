//  StructFromIterator_PluginPrincipal.m
//  StructFromIterator_Plugin
//
//  Created by Pavel on 30.05.13.
//  Copyright 2013 Pavel. All rights reserved.

#import "StructFromIterator_PluginPrincipal.h"

#import "StructFromIterator.h"

@implementation StructFromIterator_PluginPrincipal

+(void)registerNodesWithManager:(QCNodeManager*)manager
{
    KIRegisterPatch(StructFromIterator);
}

@end
