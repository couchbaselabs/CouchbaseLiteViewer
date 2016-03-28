//
//  AppDelegate.m
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 4/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "AppDelegate.h"
#import "DBWindowController.h"
#import "AppListController.h"
#import <CouchbaseLite/CouchbaseLite.h>


@implementation AppDelegate

@synthesize window=_window, urlPanel=_urlPanel, urlInputField=_urlInputField;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [AppListController restore];
}

- (BOOL) applicationShouldOpenUntitledFile:(NSApplication *)sender {
    return NO;
}

- (IBAction) showAppBrowser: (id)sender {
    [AppListController show];
}

- (IBAction) orderFrontStandardAboutPanel:(id)sender {
    NSString* cblVers = [NSString stringWithFormat: @"Couchbase Lite %@", CBLVersion()];
    [NSApp orderFrontStandardAboutPanelWithOptions: @{@"Version": cblVers}];
}


@end
