//
//  DBWindowController.m
//  TouchDB Viewer
//
//  Created by Jens Alfke on 4/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "DBWindowController.h"


@interface DBWindowController () <NSOutlineViewDataSource>
{
    @private
    CouchDatabase* _db;
    NSString* _dbPath;
    CouchLiveQuery* _query;
    NSMutableArray* _rows;
    CouchQueryRow* _selRow;
    NSMutableArray* _selRowKeys;
    
    IBOutlet NSTabView* _tabs;
    IBOutlet NSTextField* _infoField;
    IBOutlet NSOutlineView* _docsOutline;
    IBOutlet NSTableView* _propertyTable;
}

@property (readonly, nonatomic) NSString* dbPath;

@end



@implementation DBWindowController


static NSMutableArray* sControllers;


@synthesize dbPath=_dbPath;


- (id)initWithDatabase: (CouchDatabase*)db
{
    self = [super initWithWindowNibName: @"DBWindowController"];
    if (self) {
        _db = db;
        _query = [_db.getAllDocuments asLiveQuery];
        [_query addObserver: self forKeyPath: @"rows" options: NSKeyValueObservingOptionInitial context: NULL];
        
        // This keeps me from being dealloced under ARC. (Is there a better way?)
        if (!sControllers)
            sControllers = [NSMutableArray array];
        [sControllers addObject: self];
    }
    return self;
}


- (void)dealloc
{
    NSLog(@"DEALLOC %@", self);
}


- (void) windowDidLoad {
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


- (void)windowWillClose:(NSNotification *)notification {
    [sControllers removeObject: self];
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
    if (object == _query) {
        NSLog(@"------ Rows Changed -----");
        CouchQueryEnumerator* rows = _query.rows;
        _rows = rows.allObjects.mutableCopy;
        [_docsOutline reloadItem: nil];
        _infoField.stringValue = [NSString stringWithFormat: @"%lld docs — sequence #%lld",
                                  _rows.count, rows.sequenceNumber];
    }
}


- (void) outlineView:(NSOutlineView *)outlineView sortDescriptorsDidChange:(NSArray *)oldDescriptors {
    [_rows sortUsingDescriptors: outlineView.sortDescriptors];
    [outlineView reloadItem: nil];
}


#pragma mark - OUTLINE VIEW:


- (CouchQueryRow*) queryRowForItem: (id)item {
    NSAssert([item isKindOfClass: [CouchQueryRow class]], @"Invalid outline item: %@", item);
    return (CouchQueryRow*)item;
}


- (id) itemForQueryRow: (CouchQueryRow*)row {
    NSParameterAssert(row != nil);
    return row;
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
    //NSLog(@"value(%@) of %@", tableColumn.identifier, item);
    CouchQueryRow* row = [self queryRowForItem: item];
    
    static NSArray* kColumnIDs;
    if (!kColumnIDs)
        kColumnIDs = [NSArray arrayWithObjects: @"id", @"rev", @"seq", @"json", nil];
    switch ([kColumnIDs indexOfObject: tableColumn.identifier]) {
        case 0: return row.documentID;
        case 1: return formatRevision(row.documentRevision);
        case 2: return @"?"; // TODO: Local sequence #
        case 3: return formatProperties(row.document.userProperties);
        default:return @"???";
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
    //NSLog(@"child[%ld] of %@", index, item);
    if (item == nil)
        return [self itemForQueryRow: [_rows objectAtIndex: index]];
    else
        return nil;
}


- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    int row = [_docsOutline selectedRow];
    id item = row >= 0 ? [_docsOutline itemAtRow: row] : nil;
    CouchQueryRow* sel = item ? [self queryRowForItem: item] : nil;
    [self setSelectedRow: sel];
}



#pragma mark - ROW TABLE VIEW:


- (void) setSelectedRow: (CouchQueryRow*)row {
    if (row != _selRow) {
        _selRow = row;
        _selRowKeys = row.document.properties.allKeys.mutableCopy;
        [_selRowKeys sortUsingComparator: ^NSComparisonResult(NSString* key1, NSString* key2) {
            int n = ([key2 hasPrefix: @"_"] != 0) - ([key1 hasPrefix: @"_"] != 0);
            if (n)
                return n;
            return [key1 caseInsensitiveCompare: key2];
        }];
        [_propertyTable reloadData];
    }
}


- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _selRowKeys.count;
}
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(NSInteger)row
{
    id result = [_selRowKeys objectAtIndex: row];
    if (![tableColumn.identifier isEqualToString: @"key"]) {
        result = [_selRow.document.properties objectForKey: result];
        result = [RESTBody stringWithJSONObject: result];
    }
    return result;
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