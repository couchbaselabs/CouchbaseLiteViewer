//
//  DBWindowController.m
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 4/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "DBWindowController.h"
#import "DocEditor.h"
#import "QueryResultController.h"
#import "RevTreeController.h"
#import "JSONItem.h"


@interface DBWindowController () <NSOutlineViewDataSource>
{
    @private
    CBLDatabase* _db;
    NSString* _dbPath;
    NSTableColumn* _idCol, *_seqCol;

    IBOutlet QueryResultController* _queryController;
    IBOutlet RevTreeController* _revTreeController;
    IBOutlet DocEditor* _docEditor;
    IBOutlet NSOutlineView* _docsOutline;
    IBOutlet NSPathControl* _path;
    IBOutlet NSButton* _showDeletedCheckbox;
}

@end



@implementation DBWindowController


- (id)initWithDatabase: (CBLDatabase*)db atPath: (NSString*)dbPath
{
    NSParameterAssert(db != nil);
    self = [super initWithWindowNibName: @"DBWindowController"];
    if (self) {
        _db = db;
        _dbPath = dbPath.copy;
    }
    return self;
}

- (void) windowDidLoad {
    _docsOutline.target = self;
    _docsOutline.doubleAction = @selector(showDocRevisionTree:);
    
    _queryController.outline = _docsOutline;
    _queryController.query = [_db createAllDocumentsQuery];

    _docEditor.database = _db;

    [self setPath: @[_db.name]];
    
    // Set up the window title:
    self.window.title = _dbPath.lastPathComponent;
    self.window.representedFilename = _dbPath;
}


- (void) setPath: (NSArray*)path {
    NSString* urlStr = [@"foo:///" stringByAppendingString: [path componentsJoinedByString: @"/"]];
    _path.URL = [NSURL URLWithString: urlStr];
    NSArray* cells = _path.pathComponentCells;
    if (cells.count > 0)
        [cells[0] setImage: [NSImage imageNamed: @"database"]];
}


#pragma mark - CUSTOM COLUMNS:


static int jsonObjectRank(id a) {
    if (a == nil)
        return 0;
    if (a == (id)kCFNull)
        return 1;
    if (a == (id)kCFBooleanTrue || a == (id)kCFBooleanFalse)
        return 2;
    if ([a isKindOfClass: [NSNumber class]])
        return 3;
    if ([a isKindOfClass: [NSString class]])
        return 4;
    if ([a isKindOfClass: [NSArray class]])
        return 5;
    return 6;
}


static NSComparisonResult jsonCompare(id a, id b) {
    if (a == b)
        return 0;
    int rankDelta = jsonObjectRank(a) - jsonObjectRank(b);
    if (rankDelta != 0)
        return rankDelta;
    else
        return [a compare: b];
}


static void insertColumn(NSOutlineView* outline, NSTableColumn* col, NSUInteger index) {
    [outline addTableColumn: col];
    NSUInteger curIndex = [outline.tableColumns indexOfObject: col];
    if (curIndex != index)
        [outline moveColumn: curIndex toColumn: index];
}


static NSString* identifierForProperty(NSArray* propertyPath) {
    return [@"." stringByAppendingString: [propertyPath componentsJoinedByString: @"."]];
}

static NSString* asKeyPath(NSArray* path) {
    // We can convert a JSON path to a keypath unless it involves numeric indexes:
    NSMutableString* keyPath = [NSMutableString string];
    for (id key in path) {
        if (![key isKindOfClass: [NSString class]])
            return nil;
        if (keyPath.length > 0)
            [keyPath appendString: @"."];
        [keyPath appendString: key];
    }
    return keyPath;
}

static NSString* displayPath(NSArray* path) {
    NSMutableString* display = [NSMutableString string];
    for (id key in path) {
        if ([key isKindOfClass: [NSString class]]) {
            if (display.length > 0)
                [display appendString: @"."];
            [display appendString: key];
        } else {
            [display appendFormat: @"[%@]", key];
        }
    }
    return display;
}


- (BOOL) hasColumnForProperty: (NSArray*)propertyPath {
    NSString* identifier = identifierForProperty(propertyPath);
    return [_docsOutline tableColumnWithIdentifier: identifier] != nil;
}


- (void) addColumnForProperty: (NSArray*)propertyPath {
    NSString* identifier = identifierForProperty(propertyPath);
    if (![_docsOutline tableColumnWithIdentifier: identifier]) {
        NSTableColumn* col = [[NSTableColumn alloc] initWithIdentifier: identifier];
        NSTableColumn* jsonCol = [_docsOutline tableColumnWithIdentifier: @"json"];
        [col.dataCell setFont: [jsonCol.dataCell font]];

        [col.headerCell setStringValue: displayPath(propertyPath)];

        NSSortDescriptor* sort;
        NSString* keyPath = asKeyPath(propertyPath);
        if (keyPath) {
            NSString* sortKey = [@"documentProperties." stringByAppendingString: keyPath];
            sort = [NSSortDescriptor sortDescriptorWithKey: sortKey
                                           ascending:YES
                                           comparator:^NSComparisonResult(id obj1, id obj2) {
                                               return jsonCompare(obj1, obj2);
                                           }];
        } else {
            sort = [NSSortDescriptor sortDescriptorWithKey: @"documentProperties" ascending: YES
                    comparator:^NSComparisonResult(NSDictionary* doc1, NSDictionary* doc2) {
                        id val1 = [JSONItem itemAtPath: propertyPath inObject: doc1];
                        id val2 = [JSONItem itemAtPath: propertyPath inObject: doc2];
                        return jsonCompare(val1, val2);
                    }];
        }
        col.sortDescriptorPrototype = sort;
        [_queryController registerPath: propertyPath forColumn: col];
        insertColumn(_docsOutline, col, _docsOutline.tableColumns.count - 1);
    }
}


- (void) removeColumnForProperty: (NSArray*)propertyPath {
    NSString* identifier = identifierForProperty(propertyPath);
    NSTableColumn* col = [_docsOutline tableColumnWithIdentifier: identifier];
    if (col) {
        [_docsOutline removeTableColumn: col];
        [_queryController unregisterColumn: col];
    }
}


- (void) hideDocColumns {
    if (_seqCol)
        return;
    _docsOutline.outlineTableColumn = [_docsOutline tableColumnWithIdentifier: @"rev"];
    _seqCol = [_docsOutline tableColumnWithIdentifier: @"seq"];
    _idCol = [_docsOutline tableColumnWithIdentifier: @"id"];
    [_docsOutline removeTableColumn: _seqCol];
    [_docsOutline removeTableColumn: _idCol];
    [_docsOutline sizeLastColumnToFit];
}

- (void) showDocColumns {
    if (!_seqCol)
        return;
    insertColumn(_docsOutline, _seqCol, 0);
    insertColumn(_docsOutline, _idCol, 1);
    _docsOutline.outlineTableColumn = _seqCol;
    _seqCol = _idCol = nil;
    [_docsOutline sizeLastColumnToFit];
}


#pragma mark - ACTIONS:


- (id) outlineController {
    return _docsOutline.dataSource;
}


- (IBAction) showDocRevisionTree:(id)sender {
    if (_revTreeController.outline)
        return;
    NSArray* docs = _queryController.selectedDocuments;
    if (docs.count != 1)
        return;

    CBLDocument* doc = docs[0];
    [self hideDocColumns];
    [self willChangeValueForKey: @"outlineController"];
    _revTreeController.document = doc;
    _queryController.outline = nil;
    _revTreeController.outline = _docsOutline;
    [self didChangeValueForKey: @"outlineController"];
    [self setPath: @[_db.name, doc.documentID]];
}


- (IBAction) hideDocRevisionTree: (id)sender {
    if (_queryController.outline)
        return;
    [self showDocColumns];
    CBLDocument* doc = _revTreeController.document;
    [self willChangeValueForKey: @"outlineController"];
    _revTreeController.document = nil;
    _revTreeController.outline = nil;
    _queryController.outline = _docsOutline;
    [_queryController selectDocument: doc];
    [self didChangeValueForKey: @"outlineController"];
    [self setPath: @[_db.name]];
}


- (IBAction) pathClicked: (id)sender {
    NSUInteger index = [_path.pathComponentCells indexOfObjectIdenticalTo: _path.clickedPathComponentCell];
    if (index == 0)
        [self hideDocRevisionTree: sender];
}


- (IBAction) newDocument: (id)sender {
    [_queryController newDocument: sender];
}


- (IBAction) deleteDocument: (id)sender {
    [_queryController deleteDocument: sender];
}


- (void) keyDown: (NSEvent*)ev {
    if (ev.type == NSKeyDown) {
        NSString* keys = ev.characters;
        if (keys.length == 1) {
            unichar key = [keys characterAtIndex: 0];
            if (key == 0x7F || key == NSDeleteCharFunctionKey) {
                // Delete key -- delete from focused table view:
                NSResponder* responder = [self.window firstResponder];
                if (responder == _docsOutline) {
                    [self deleteDocument: self];
                    return;
                } else if (responder == _docEditor.tableView) {
                    [_docEditor removeProperty: self];
                    return;
                }
            }
        }
    }
    NSBeep();
}


- (IBAction) copy:(id)sender {
    id focus = self.window.firstResponder;
    if ([focus isKindOfClass: [NSTableView class]]) {
        focus = [focus delegate];
        if ([focus respondsToSelector: @selector(copy:)]) {
            [focus copy: sender];
            return;
        }
    }
    NSBeep();
}


@end
