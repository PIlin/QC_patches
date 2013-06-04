//  StructFromIterator_PluginPrincipal
//  StructFromIterator_Plugin
//
//  Created by Pavel on 30.05.13.
//  Copyright 2013 Pavel. All rights reserved.

@interface StructFromIterator_PluginPrincipal : NSObject <GFPlugInRegistration>
+(void)registerNodesWithManager:(QCNodeManager*)manager;
@end
