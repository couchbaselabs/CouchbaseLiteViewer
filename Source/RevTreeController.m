//
//  RevTreeController.m
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 8/29/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "RevTreeController.h"
#import "DocEditor.h"
#import "DocHistory.h"


static NSFont* sFont, *sBoldFont;

static void enableCell(NSTextFieldCell *cell, BOOL enabled);
static void emboldenCell(NSTextFieldCell *cell, BOOL embolden);


@interface RevTreeController ()
{
    CBLDocument* _document;
    NSTreeNode* _fullRoot;  // includes deleted revs
    NSTreeNode* _root;  // may not include deleted revs
    NSSet* _leaves;
    BOOL _showDeleted;
    
    IBOutlet DocEditor* _docEditor;
    IBOutlet NSOutlineView* _docsOutline;
    IBOutlet NSButton *_addDocButton, *_removeDocButton;
}
@end



@implementation RevTreeController


- (NSOutlineView*) outline {
    return _docsOutline;
}

- (void) setOutline: (NSOutlineView*)outline {
    if (_docsOutline && sFont) {
        // Restore font of rev column (may have been left bolded)
        NSTextFieldCell* cell = [_docsOutline tableColumnWithIdentifier: @"rev"].dataCell;
        cell.font = sFont;
    }
    _docsOutline.dataSource = nil;
    _docsOutline.delegate = nil;
    _docsOutline = outline;

    if (outline) {
        outline.dataSource = self;
        outline.delegate = self;
        [outline reloadData];
        [outline expandItem: nil expandChildren: YES];
        [self outlineViewSelectionDidChange];
        _addDocButton.enabled = _removeDocButton.enabled = NO;
    }
}


- (CBLDocument*) document {
    return _document;
}

- (void) setDocument:(CBLDocument *)document {
    _document = document;
    _fullRoot = document ? GetDocRevisionTree(document) : nil;
    if (!_showDeleted && _document.currentRevision.isDeletion)
        self.showDeleted = YES;
    else
        [self updateRoot];
}


- (void) updateRoot {
    _root = _showDeleted ? CopyTree(_fullRoot) : TreeWithoutDeletedBranches(_fullRoot);
    _leaves = GetLeafNodes(_root);
    FlattenTree(_root);
}


- (BOOL) showDeleted {
    return _showDeleted;
}

- (void) setShowDeleted:(BOOL)showDeleted {
    _showDeleted = showDeleted;
    [self updateRoot];
    [_docsOutline reloadData];
}


- (NSArray*) selectedRevisions {
    NSIndexSet* selIndexes = [_docsOutline selectedRowIndexes];
    NSUInteger count = selIndexes.count;
    NSMutableArray* sel = [NSMutableArray arrayWithCapacity: count];
    [selIndexes enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop) {
        CBLSavedRevision* item = [self revisionForItem: [self->_docsOutline itemAtRow: idx]];
        [sel addObject: item];
    }];
    return sel;
}


#pragma mark - REVISION-LIST VIEW:


- (CBLSavedRevision*) revisionForItem: (id)item {
    NSAssert(item==nil || [item isKindOfClass: [NSTreeNode class]], @"Invalid outline item: %@", item);
    return [item representedObject];
}


static NSString* formatRevision( NSString* revID ) {
    if (revID.length >= 2 && [revID characterAtIndex: 1] == '-')
        revID = [@" " stringByAppendingString: revID];
    return revID;
}

static NSString* formatProperty( id property ) {
    return property ? [CBLJSON stringWithJSONObject: property options: 0 error: NULL] : nil;
}


- (id)outlineView:(NSOutlineView *)outlineView 
      objectValueForTableColumn:(NSTableColumn *)tableColumn
                         byItem:(id)item
{
    CBLSavedRevision* rev = [self revisionForItem: item];
    NSString* identifier = tableColumn.identifier;
    
    if ([identifier hasPrefix: @"."]) {
        NSString* property = [identifier substringFromIndex: 1];
        return formatProperty(rev[property]);
    } else {
        static NSArray* kColumnIDs;
        if (!kColumnIDs)
            kColumnIDs = @[@"id", @"rev", @"json"];
        switch ([kColumnIDs indexOfObject: identifier]) {
            case 0: return rev.document.documentID;
            case 1: return formatRevision(rev.revisionID);
            case 2: {
                if (!rev.propertiesAvailable)
                    return @"missing";
                NSDictionary* userProps = rev.userProperties;
                return userProps.count ? formatProperty(userProps) : nil;
            }
            default:return @"???";
        }
    }
}


- (void) outlineView:(NSOutlineView *)outlineView
        willDisplayCell:(id)cell
         forTableColumn:(NSTableColumn *)col
                   item:(id)item
{
    NSString* identifier = col.identifier;
    CBLSavedRevision* rev = [self revisionForItem: item];
    if ([identifier isEqualToString: @"rev"]) {
        enableCell(cell, !rev.isDeletion);
        emboldenCell(cell, [_leaves containsObject: item] && !rev.isDeletion);
    } else if ([identifier isEqualToString: @"json"]) {
        enableCell(cell, rev.propertiesAvailable);
    }
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    item = item ?: _root;
    return ![item isLeaf];
}


- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    item = item ?: _root;
    return [[item childNodes] count];
}


- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    item = item ?: _root;
    return [item childNodes][index];
}


- (BOOL)selectionShouldChangeInOutlineView:(NSOutlineView *)outlineView {
    return [_docEditor saveDocument];
}


- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    [self outlineViewSelectionDidChange];
}

- (void)outlineViewSelectionDidChange {
    CBLSavedRevision* sel = nil;
    NSIndexSet* selRows = [_docsOutline selectedRowIndexes];
    if (selRows.count == 1) {
        id item = [_docsOutline itemAtRow: [selRows firstIndex]]; 
        sel = item ? [self revisionForItem: item] : nil;
    }
    _docEditor.readOnly = YES;
    _docEditor.revision = sel;
}


#pragma mark - ACTIONS:


- (IBAction) copy:(id)sender {
    NSArray* sel = self.selectedRevisions;
    if (!sel.count) {
        NSBeep();
        return;
    }
    NSMutableArray* revIDs = [NSMutableArray array];
    for (CBLSavedRevision* rev in sel)
        [revIDs addObject: rev.revisionID];
    NSString* result = [revIDs componentsJoinedByString: @"\n"];

    NSPasteboard* pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString: result forType: NSStringPboardType];
}


@end




static void enableCell(NSTextFieldCell *cell, BOOL enabled) {
    NSColor* color =  enabled ? [NSColor controlTextColor]
    : [NSColor disabledControlTextColor];
    [cell setTextColor: color];
}

static void emboldenCell(NSTextFieldCell *cell, BOOL embolden) {
    if (!sFont) {
        sFont = [cell font];
        sBoldFont = [[NSFontManager sharedFontManager] convertFont: sFont
                                                       toHaveTrait: NSBoldFontMask];
    }
    [cell setFont: (embolden ? sBoldFont : sFont)];
}
