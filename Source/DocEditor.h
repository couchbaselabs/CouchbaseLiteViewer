//
//  DocEditor.h
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 5/4/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@class DBWindowController;


@interface DocEditor : NSObject

@property (weak) CBLDatabase* database;

@property (weak) CBLRevision* revision;

@property BOOL readOnly;

- (void) editNewDocument;

- (IBAction) addProperty: (id)sender;
- (IBAction) removeProperty: (id)sender;

- (IBAction) addColumnForSelectedProperty:(id)sender;

@property (weak, readonly) NSTableView* tableView;

@property (copy) NSString* selectedProperty;

- (IBAction) saveDocument: (id)sender;
- (IBAction) revertDocumentToSaved:(id)sender;

- (BOOL) saveDocument;
- (IBAction) cancelOperation: (id)sender;
- (IBAction) copy:(id)sender;

@end
