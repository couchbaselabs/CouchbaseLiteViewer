//
//  DBWindowController.h
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 4/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class CBLDatabase, DocEditor;


@interface DBWindowController : NSWindowController

- (id)initWithDatabase: (CBLDatabase*)db atPath: (NSString*)dbPath;

- (IBAction) showDocRevisionTree:(id)sender;
- (IBAction) newDocument: (id)sender;
- (IBAction) deleteDocument: (id)sender;

/** Either the QueryResultController or the RevTreeController */
@property (unsafe_unretained, readonly) id outlineController;

- (BOOL) hasColumnForProperty: (NSString*)property;
- (void) addColumnForProperty: (NSString*)property;
- (void) removeColumnForProperty: (NSString*)property;

@end
