//
//  AppListController.h
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 9/25/13.
//  Copyright (c) 2013 Couchbase, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppListController : NSWindowController

+ (void) show;
+ (void) restore;

@end
