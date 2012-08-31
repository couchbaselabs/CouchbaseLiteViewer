//
//  DocEditor.h
//  TouchDB Viewer
//
//  Created by Jens Alfke on 5/4/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@class DBWindowController;


@interface DocEditor : NSObject

@property CouchDatabase* database;

@property CouchRevision* revision;

@property BOOL readOnly;

- (void) editNewDocument;

- (IBAction) addProperty: (id)sender;
- (IBAction) removeProperty: (id)sender;

- (IBAction) addColumnForSelectedProperty:(id)sender;

@property (readonly) NSTableView* tableView;

@property (copy) NSString* selectedProperty;

- (IBAction) saveDocument: (id)sender;
- (IBAction) revertDocumentToSaved:(id)sender;

- (BOOL) saveDocument;
- (IBAction) cancelOperation: (id)sender;
- (IBAction) copy:(id)sender;

@end
