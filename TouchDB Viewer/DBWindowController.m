//
//  DBWindowController.m
//  TouchDB Viewer
//
//  Created by Jens Alfke on 4/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "DBWindowController.h"
#import "DocEditor.h"


@interface DBWindowController () <NSOutlineViewDataSource>
{
    @private
    CouchDatabase* _db;
    NSString* _dbPath;
    CouchLiveQuery* _query;
    NSMutableArray* _rows;
    
    IBOutlet DocEditor* _docEditor;
    IBOutlet NSTabView* _tabs;
    IBOutlet NSTextField* _infoField;
    IBOutlet NSOutlineView* _docsOutline;
    IBOutlet NSButton *_addDocButton, *_removeDocButton;
}

@property (readonly, nonatomic) NSString* dbPath;

@end



@implementation DBWindowController


@synthesize dbPath=_dbPath;


- (id)initWithDatabase: (CouchDatabase*)db
{
    self = [super initWithWindowNibName: @"DBWindowController"];
    if (self) {
        _db = db;
        _query = [_db.getAllDocuments asLiveQuery];
        _query.prefetch = _query.sequences = YES;
        [_query addObserver: self forKeyPath: @"rows"
                    options: NSKeyValueObservingOptionInitial
                    context: NULL];
    }
    return self;
}


- (void)dealloc
{
    [_query removeObserver: self forKeyPath: @"rows"];
}


- (void) windowDidLoad {
    _docEditor.database = _db;
    
    // Set up the window title:
    if (_dbPath) {
        self.window.title = _dbPath.lastPathComponent;
        self.window.representedFilename = _dbPath;
    } else {
        // Remote database:
        NSURL* url = _db.URL;
        NSString* host = url.host;
        NSNumber* port = url.port;
        if (port && port.intValue != 80)
            host = [host stringByAppendingFormat: @":%@", port];
        self.window.title = [NSString stringWithFormat: @"%@ <%@>",
                             _db.relativePath, host];
    }
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
    if (object == _query) {
        NSArray* selection;
        CouchDocument* editedDoc = _docEditor.revision.document;
        if (editedDoc)
            selection = [NSArray arrayWithObject: editedDoc];
        else
            selection = self.selectedDocuments;
        
        CouchQueryEnumerator* rows = _query.rows;
        _rows = rows.allObjects.mutableCopy;
        if (_docsOutline.sortDescriptors)
            [_rows sortUsingDescriptors: _docsOutline.sortDescriptors];
        [_docsOutline reloadItem: nil];
        _infoField.stringValue = [NSString stringWithFormat: @"%lld docs — sequence #%lld",
                                  _rows.count, rows.sequenceNumber];
        
        self.selectedDocuments = selection;
    }
}


- (void) outlineView:(NSOutlineView *)outlineView
         sortDescriptorsDidChange:(NSArray *)oldDescriptors {
    [_rows sortUsingDescriptors: outlineView.sortDescriptors];
    [outlineView reloadItem: nil];
}


- (NSArray*) selectedRows {
    NSIndexSet* selIndexes = [_docsOutline selectedRowIndexes];
    NSUInteger count = selIndexes.count;
    NSMutableArray* sel = [NSMutableArray arrayWithCapacity: count];
    [selIndexes enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop) {
        CouchQueryRow* item = [self queryRowForItem: [_docsOutline itemAtRow: idx]]; 
        [sel addObject: item];
    }];
    return sel;
}


- (NSArray*) selectedDocuments {
    NSMutableArray* docs = [NSMutableArray array];
    for (CouchQueryRow* row in self.selectedRows)
        [docs addObject: row.document];
    return docs;
}


- (void) setSelectedDocuments: (NSArray*)sel {
    NSMutableIndexSet* selIndexes = [NSMutableIndexSet indexSet];
    for (CouchDocument* doc in sel) {
        CouchQueryRow* queryRow = [self queryRowForDocument: doc];
        if (queryRow) {
            int row = [_docsOutline rowForItem: [self itemForQueryRow: queryRow]];
            if (row >= 0)
                [selIndexes addIndex: row];
        }
    }
    [_docsOutline selectRowIndexes: selIndexes byExtendingSelection: NO];
}


- (BOOL) selectDocument: (CouchDocument*)doc {
    CouchQueryRow* queryRow = [self queryRowForDocument: doc];
    if (queryRow) {
        int row = [_docsOutline rowForItem: [self itemForQueryRow: queryRow]];
        if (row >= 0) {
            [_docsOutline selectRowIndexes: [NSIndexSet indexSetWithIndex: row]
                      byExtendingSelection: NO];
            return YES;
        }
    }
    return NO;
}


#pragma mark - DOCUMENT-LIST VIEW:


- (CouchQueryRow*) queryRowForItem: (id)item {
    NSAssert([item isKindOfClass: [CouchQueryRow class]], @"Invalid outline item: %@", item);
    return (CouchQueryRow*)item;
}


- (id) itemForQueryRow: (CouchQueryRow*)row {
    NSParameterAssert(row != nil);
    return row;
}


- (CouchQueryRow*) queryRowForDocument: (CouchDocument*)doc {
    NSString* docID = doc.documentID;
    for (CouchQueryRow* row in _rows) {
        if ([row.documentID isEqualToString: docID])
            return row;
    }
    return nil;
}


static NSString* formatRevision( NSString* revID ) {
    if (revID.length >= 2 && [revID characterAtIndex: 1] == '-')
        revID = [@" " stringByAppendingString: revID];
    return revID;
}

static NSString* formatProperties( NSDictionary* props ) {
    return props ? [RESTBody stringWithJSONObject: props] : nil;
}


- (id)outlineView:(NSOutlineView *)outlineView 
      objectValueForTableColumn:(NSTableColumn *)tableColumn
                         byItem:(id)item
{
    CouchQueryRow* row = [self queryRowForItem: item];
    NSString* identifier = tableColumn.identifier;
    
    if ([identifier hasPrefix: @"."]) {
        NSString* property = [identifier substringFromIndex: 1];
        id value = [row.documentProperties objectForKey: property];
        return formatProperties(value);
    } else {
        static NSArray* kColumnIDs;
        if (!kColumnIDs)
            kColumnIDs = [NSArray arrayWithObjects: @"id", @"rev", @"seq", @"json", nil];
        switch ([kColumnIDs indexOfObject: identifier]) {
            case 0: return row.documentID;
            case 1: return formatRevision(row.documentRevision);
            case 2: return [NSNumber numberWithUnsignedLongLong: row.localSequence];
            case 3: return formatProperties(row.document.userProperties);
            default:return @"???";
        }
    }
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return item == nil;
}


- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item == nil)
        return _rows.count;
    else
        return 0;
}


- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (item == nil)
        return [self itemForQueryRow: [_rows objectAtIndex: index]];
    else
        return nil;
}


- (BOOL)selectionShouldChangeInOutlineView:(NSOutlineView *)outlineView {
    return [_docEditor saveDocument];
}


- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    [self enableDocumentButtons];
    
    CouchQueryRow* sel = nil;
    NSIndexSet* selRows = [_docsOutline selectedRowIndexes];
    if (selRows.count == 1) {
        id item = [_docsOutline itemAtRow: [selRows firstIndex]]; 
        sel = item ? [self queryRowForItem: item] : nil;
    }
    [_docEditor setRevision: sel.document.currentRevision];
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


- (BOOL) hasColumnForProperty: (NSString*)property {
    NSString* identifier = [@"." stringByAppendingString: property];
    return [_docsOutline tableColumnWithIdentifier: identifier] != nil;
}


- (void) addColumnForProperty: (NSString*)property {
    NSString* identifier = [@"." stringByAppendingString: property];
    if (![_docsOutline tableColumnWithIdentifier: identifier]) {
        NSTableColumn* col = [[NSTableColumn alloc] initWithIdentifier: identifier];
        [col.headerCell setStringValue: identifier];
        NSTableColumn* jsonCol = [_docsOutline tableColumnWithIdentifier: @"json"];
        [col.dataCell setFont: [jsonCol.dataCell font]];
        
        NSString* sortKey = [@"documentProperties." stringByAppendingString: property];
        col.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey: sortKey
                                       ascending:YES
                                       comparator:^NSComparisonResult(id obj1, id obj2) {
                                           return jsonCompare(obj1, obj2);
                                       }];
        
        
        [_docsOutline addTableColumn: col];
        NSUInteger index = [_docsOutline.tableColumns indexOfObject: col];
        [_docsOutline moveColumn: index toColumn: _docsOutline.tableColumns.count - 2];
    }
}


- (void) removeColumnForProperty: (NSString*)property {
    NSString* identifier = [@"." stringByAppendingString: property];
    NSTableColumn* col = [_docsOutline tableColumnWithIdentifier: identifier];
    if (col)
        [_docsOutline removeTableColumn: col];
}


#pragma mark - ACTIONS:


- (void) enableDocumentButtons {
    [_removeDocButton setEnabled: (_docsOutline.selectedRow >= 0)];
}


- (IBAction) newDocument: (id)sender {
    [_docsOutline selectRowIndexes: nil byExtendingSelection: NO];
    [_docEditor editNewDocument];
}


- (IBAction) deleteDocument: (id)sender {
    NSArray* sel = self.selectedDocuments;
    if (sel.count == 0) {
        NSBeep();
        return;
    }
    NSError* error;
    if (![[_db deleteDocuments: sel] wait: &error]) {
        [self presentError: error];
    }
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


@end



@interface NSString (DBWindowController)
- (NSComparisonResult) revID_compare: (NSString*)str;
@end

@implementation NSString (DBWindowController)

- (NSComparisonResult) revID_compare: (NSString*)str {
    return [self compare: str options: NSNumericSearch];
}

@end