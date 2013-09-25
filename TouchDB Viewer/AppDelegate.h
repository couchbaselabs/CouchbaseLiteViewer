//
//  AppDelegate.h
//  TouchDB Viewer
//
//  Created by Jens Alfke on 4/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSPanel* urlPanel;
@property (weak) IBOutlet NSTextField *urlInputField;

- (IBAction) dismissURLPanel:(id)sender;
@end
