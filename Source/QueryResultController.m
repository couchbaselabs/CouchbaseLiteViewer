//
//  QueryResultController.m
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 8/29/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "QueryResultController.h"
#import "DocEditor.h"


@interface QueryResultController ()
{
@private
    CBLLiveQuery* _query;
    NSMutableArray* _rows;
    NSOutlineView* _docsOutline;

    IBOutlet DocEditor* _docEditor;
    IBOutlet NSButton *_addDocButton, *_removeDocButton;
}
@end



@implementation QueryResultController


- (CBLQuery*)query {
    return _query;
}

- (void) setQuery: (CBLQuery*)query
{
    if (_query)
        [_query removeObserver: self forKeyPath: @"rows"];
    query.prefetch = YES;
    _query = [query asLiveQuery];
    [_query addObserver: self forKeyPath: @"rows"
                options: NSKeyValueObservingOptionInitial
                context: NULL];
    [_query addObserver: self forKeyPath: @"error"
                options: 0
                context: NULL];
    [_query start];
}


- (NSOutlineView*) outline {
    return _docsOutline;
}

- (void) setOutline: (NSOutlineView*)outline {
    _docsOutline.dataSource = nil;
    _docsOutline.delegate = nil;
    _docsOutline = outline;
    outline.dataSource = self;
    outline.delegate = self;
    [outline reloadData];
    [self enableDocumentButtons];
}


- (BOOL) showDeleted {
    return _query.allDocsMode == kCBLIncludeDeleted;
}

- (void) setShowDeleted:(BOOL)showDeleted {
    _query.allDocsMode = showDeleted ? kCBLIncludeDeleted : kCBLAllDocs;
    [_query start];
}


- (void)dealloc
{
    [_query removeObserver: self forKeyPath: @"rows"];
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
    if (object == _query) {
        if (_query.lastError) {
            [_docsOutline.window presentError: _query.lastError];
        } else {
            NSArray* selection;
            CBLDocument* editedDoc = _docEditor.revision.document;
            if (editedDoc)
                selection = @[editedDoc];
            else
                selection = self.selectedDocuments;

            CBLQueryEnumerator* rows = _query.rows;
            _rows = rows.allObjects.mutableCopy;
            if (_docsOutline.sortDescriptors)
                [_rows sortUsingDescriptors: _docsOutline.sortDescriptors];
            [_docsOutline reloadData];

            self.selectedDocuments = selection;
        }
    }
}


- (void) outlineView:(NSOutlineView *)outlineView
         sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
    [_rows sortUsingDescriptors: outlineView.sortDescriptors];
    [outlineView reloadData];
}


- (NSArray*) selectedRows {
    NSIndexSet* selIndexes = [_docsOutline selectedRowIndexes];
    NSUInteger count = selIndexes.count;
    NSMutableArray* sel = [NSMutableArray arrayWithCapacity: count];
    [selIndexes enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop) {
        CBLQueryRow* item = [self queryRowForItem: [_docsOutline itemAtRow: idx]];
        [sel addObject: item];
    }];
    return sel;
}


- (NSArray*) selectedDocuments {
    NSMutableArray* docs = [NSMutableArray array];
    for (CBLQueryRow* row in self.selectedRows)
        [docs addObject: row.document];
    return docs;
}


- (void) setSelectedDocuments: (NSArray*)sel {
    NSMutableIndexSet* selIndexes = [NSMutableIndexSet indexSet];
    for (CBLDocument* doc in sel) {
        CBLQueryRow* queryRow = [self queryRowForDocument: doc];
        if (queryRow) {
            NSInteger row = [_docsOutline rowForItem: [self itemForQueryRow: queryRow]];
            if (row >= 0)
                [selIndexes addIndex: row];
        }
    }
    [_docsOutline selectRowIndexes: selIndexes byExtendingSelection: NO];
}


- (BOOL) selectDocument: (CBLDocument*)doc {
    CBLQueryRow* queryRow = [self queryRowForDocument: doc];
    if (queryRow) {
        NSInteger row = [_docsOutline rowForItem: [self itemForQueryRow: queryRow]];
        if (row >= 0) {
            [_docsOutline selectRowIndexes: [NSIndexSet indexSetWithIndex: row]
                      byExtendingSelection: NO];
            return YES;
        }
    }
    return NO;
}


#pragma mark - DOCUMENT-LIST VIEW:


- (CBLQueryRow*) queryRowForItem: (id)item {
    NSAssert([item isKindOfClass: [CBLQueryRow class]], @"Invalid outline item: %@", item);
    return (CBLQueryRow*)item;
}


- (id) itemForQueryRow: (CBLQueryRow*)row {
    NSParameterAssert(row != nil);
    return row;
}


- (CBLQueryRow*) queryRowForDocument: (CBLDocument*)doc {
    NSString* docID = doc.documentID;
    for (CBLQueryRow* row in _rows) {
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

static NSString* formatProperty( id property ) {
    if (!property)
        return nil;
    NSString* result =[CBLJSON stringWithJSONObject: property
                                            options: CBLJSONWritingAllowFragments
                                              error: NULL];
    if (result.length > 200)
        result = [[result substringToIndex: 200] stringByAppendingString: @"…"];
    return result;
}


- (id)outlineView:(NSOutlineView *)outlineView 
      objectValueForTableColumn:(NSTableColumn *)tableColumn
                         byItem:(id)item
{
    CBLQueryRow* row = [self queryRowForItem: item];
    NSString* identifier = tableColumn.identifier;
    
    if ([identifier hasPrefix: @"."]) {
        NSString* property = [identifier substringFromIndex: 1];
        id value = (row.documentProperties)[property];
        return formatProperty(value);
    } else {
        static NSArray* kColumnIDs;
        if (!kColumnIDs)
            kColumnIDs = @[@"id", @"rev", @"seq", @"json"];
        switch ([kColumnIDs indexOfObject: identifier]) {
            case 0: return row.documentID;
            case 1: return formatRevision(row.documentRevisionID);
            case 2: return @(row.sequenceNumber);
            case 3: return formatProperty(row.document.userProperties);
            default:return @"???";
        }
    }
}


- (void) outlineView:(NSOutlineView *)outlineView
     willDisplayCell:(NSTextFieldCell*)cell
      forTableColumn:(NSTableColumn *)col
                item:(NSTreeNode*)item
{
    CBLQueryRow* row = [self queryRowForItem: item];
    BOOL deleted = [row.value[@"deleted"] boolValue];
    NSColor* color =  deleted ? [NSColor disabledControlTextColor]
                              : [NSColor controlTextColor];
    [cell setTextColor: color];
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
        return [self itemForQueryRow: _rows[index]];
    else
        return nil;
}


- (BOOL)selectionShouldChangeInOutlineView:(NSOutlineView *)outlineView {
    return [_docEditor saveDocument];
}


- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    [self enableDocumentButtons];
    
    CBLQueryRow* sel = nil;
    NSIndexSet* selRows = [_docsOutline selectedRowIndexes];
    if (selRows.count == 1) {
        id item = [_docsOutline itemAtRow: [selRows firstIndex]]; 
        sel = item ? [self queryRowForItem: item] : nil;
    }
    _docEditor.readOnly = NO;
    [_docEditor setRevision: sel.document.currentRevision];
}


#pragma mark - ACTIONS:


- (void) enableDocumentButtons {
    _addDocButton.enabled = YES;
    _removeDocButton.enabled = (_docsOutline.selectedRow >= 0);
}


- (IBAction) newDocument: (id)sender {
    [_docsOutline deselectAll: nil];
    [_docEditor editNewDocument];
}


- (IBAction) deleteDocument: (id)sender {
    NSArray* sel = self.selectedDocuments;
    if (sel.count == 0) {
        NSBeep();
        return;
    }
    __block NSError* error;
    BOOL ok = [_query.database inTransaction:^BOOL{
        for (CBLDocument* doc in sel) {
            if (![doc deleteDocument: &error])
                return NO;
        }
        return YES;
    }];
    if (!ok) {
        [_docsOutline presentError: error];
    }
}


- (IBAction) copy:(id)sender {
    NSArray* docs = self.selectedDocuments;
    if (!docs.count) {
        NSBeep();
        return;
    }
    NSMutableArray* docIDs = [NSMutableArray array];
    for (CBLDocument* doc in docs)
        [docIDs addObject: doc.documentID];
    NSString* result = [docIDs componentsJoinedByString: @"\n"];

    NSPasteboard* pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString: result forType: NSStringPboardType];
}


@end



@interface NSString (QueryResultController)
- (NSComparisonResult) revID_compare: (NSString*)str;
@end

@implementation NSString (QueryResultController)

- (NSComparisonResult) revID_compare: (NSString*)str {
    return [self compare: str options: NSNumericSearch];
}

@end
