//
//  AppDelegate.h
//  TouchDB Viewer
//
//  Created by Jens Alfke on 4/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSPanel* urlPanel;
@property (assign) IBOutlet NSTextField *urlInputField;

- (IBAction) dismissURLPanel:(id)sender;
@end
