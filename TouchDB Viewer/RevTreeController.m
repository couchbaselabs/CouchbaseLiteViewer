//
//  RevTreeController.m
//  TouchDB Viewer
//
//  Created by Jens Alfke on 8/29/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "RevTreeController.h"
#import "DocEditor.h"
#import "DocHistory.h"


@interface RevTreeController ()
{
    CouchDocument* _document;
    NSTreeNode* _root;
    
    IBOutlet DocEditor* _docEditor;
    IBOutlet NSOutlineView* _docsOutline;
}
@end



@implementation RevTreeController


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
    [self outlineViewSelectionDidChange: nil];
}


- (CouchDocument*) document {
    return _document;
}

- (void) setDocument:(CouchDocument *)document {
    _document = document;
    _root = document ? GetDocRevisionTree(document) : nil;
}


#pragma mark - DOCUMENT-LIST VIEW:


- (CouchRevision*) revisionForItem: (id)item {
    NSAssert(item==nil || [item isKindOfClass: [NSTreeNode class]], @"Invalid outline item: %@", item);
    return [item representedObject];
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
    CouchRevision* rev = [self revisionForItem: item];
    NSString* identifier = tableColumn.identifier;
    
    if ([identifier hasPrefix: @"."]) {
        NSString* property = [identifier substringFromIndex: 1];
        id value = [rev.properties objectForKey: property];
        return formatProperties(value);
    } else {
        static NSArray* kColumnIDs;
        if (!kColumnIDs)
            kColumnIDs = [NSArray arrayWithObjects: @"id", @"rev", @"json", nil];
        switch ([kColumnIDs indexOfObject: identifier]) {
            case 0: return rev.documentID;
            case 1: return formatRevision(rev.revisionID);
            case 2: return formatProperties(rev.userProperties);
            default:return @"???";
        }
    }
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    item = item ?: _root;
    return [[item childNodes] count] > 0;
}


- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    item = item ?: _root;
    return [[item childNodes] count];
}


- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    item = item ?: _root;
    return [[item childNodes] objectAtIndex: index];
}


- (BOOL)selectionShouldChangeInOutlineView:(NSOutlineView *)outlineView {
    return [_docEditor saveDocument];
}


- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    CouchRevision* sel = nil;
    NSIndexSet* selRows = [_docsOutline selectedRowIndexes];
    if (selRows.count == 1) {
        id item = [_docsOutline itemAtRow: [selRows firstIndex]]; 
        sel = item ? [self revisionForItem: item] : nil;
    }
    _docEditor.readOnly = YES;
    _docEditor.revision = sel;
}


@end
