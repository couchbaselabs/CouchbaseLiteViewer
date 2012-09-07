//
//  AppDelegate.m
//  TouchDB Viewer
//
//  Created by Jens Alfke on 4/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "AppDelegate.h"
#import "DBWindowController.h"


@implementation AppDelegate

@synthesize window=_window, urlPanel=_urlPanel, urlInputField=_urlInputField;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //gRESTLogLevel = kRESTLogRequestHeaders;
}

- (BOOL) applicationShouldOpenUntitledFile:(NSApplication *)sender {
    return NO;
}

- (IBAction) openURL:(id)sender {
    [_urlPanel center];
    NSInteger code = [NSApp runModalForWindow: _urlPanel];
    NSURL* url = _urlInputField.objectValue;
    [_urlPanel orderOut: self];
    if (code == NSOKButton && url) {
        DBWindowController* controller = [[DBWindowController alloc] initWithURL: url];
        if (controller)
            [controller showWindow: self];
        else
            NSBeep();
    }
}

- (IBAction) dismissURLPanel: (id)sender
{
    NSInteger code = [sender tag];
    if (code == NSOKButton && !_urlInputField.objectValue) {
        NSBeep();
        return;
    }
    [NSApp stopModalWithCode: code];
}

@end
