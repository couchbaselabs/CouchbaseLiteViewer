//
//  DBWindowController.h
//  TouchDB Viewer
//
//  Created by Jens Alfke on 4/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class CouchDatabase, DocEditor;


@interface DBWindowController : NSWindowController

- (id)initWithDatabase: (CouchDatabase*)db;

- (IBAction) showDocRevisionTree:(id)sender;
- (IBAction) newDocument: (id)sender;
- (IBAction) deleteDocument: (id)sender;

- (BOOL) hasColumnForProperty: (NSString*)property;
- (void) addColumnForProperty: (NSString*)property;
- (void) removeColumnForProperty: (NSString*)property;

@end
