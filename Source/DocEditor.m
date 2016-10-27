//
//  DocEditor.m
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 5/4/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "DocEditor.h"
#import "DBWindowController.h"
#import "JSONFormatter.h"
#import "JSONItem.h"
#import "JSONKeyFormatter.h"
#import <CouchbaseLite/CouchbaseLite.h>


@implementation DocEditor
{
    CBLDatabase* __weak _db;
    CBLSavedRevision* _revision;
    BOOL _readOnly;
    BOOL _untitled;
    JSONItem* _root;
    int _editErrorCount;
    BOOL _cancelingEdit;
    
    IBOutlet DBWindowController* _dbWindowController;
    IBOutlet NSOutlineView* __weak _outline;
    IBOutlet NSButton *_addPropertyButton, *_removePropertyButton;
    IBOutlet NSButton *_saveButton, *_revertButton;
    IBOutlet JSONKeyFormatter *_keyFormatter;
}


@synthesize database=_db, tableView=_outline, readOnly=_readOnly;


- (void) awakeFromNib {
    NSLayoutConstraint* c = [NSLayoutConstraint constraintWithItem: _addPropertyButton
                                                         attribute: NSLayoutAttributeLeft
                                                         relatedBy: NSLayoutRelationEqual
                                                            toItem: _outline
                                                         attribute: NSLayoutAttributeLeft
                                                        multiplier: 1.0 constant: 0];
    [_outline.window.contentView addConstraint: c];
}


- (CBLSavedRevision*) revision {
    return _revision;
}

- (void) setRevision: (CBLSavedRevision*)rev {
    if ((rev != _revision && ![rev isEqual: _revision]) || _untitled) {
        _revision = rev;
        _untitled = NO;
        [self revertDocumentToSaved: self];
    }
}


- (void) editNewDocument {
    if (!_untitled) {
        _revision = nil;
        _untitled = YES;
        [self revertDocumentToSaved: self];
    }
}


- (void) rebuildTable {
    if (_revision) {
        _root = [[JSONItem alloc] initWithValue: _revision.properties];
    } else if (_untitled) {
        NSString* docID = [NSUUID UUID].UUIDString;
        _root = [[JSONItem alloc] initWithValue: @{@"_id": docID}];
    } else {
        _root = nil;
    }
    [_outline reloadData];
}

- (void) reloadItem: (JSONItem*)item {
    if (item == _root)
        item = nil;
    [_outline reloadItem: item reloadChildren: YES];
}

- (void) redrawItem: (JSONItem*)item {
    NSInteger row = [_outline rowForItem: item];
    if (row >= 0)
        [_outline setNeedsDisplayInRect: [_outline rectOfRow: row]];
}


- (JSONItem*) selectedProperty {
    NSInteger row = _outline.selectedRow;
    return row >= 0 ? [_outline itemAtRow: row] : nil;
}


- (void) setSelectedProperty: (JSONItem*)property {
    NSUInteger row = [_outline rowForItem: property];
    NSIndexSet* indexes = nil;
    if (row != NSNotFound)
        indexes = [NSIndexSet indexSetWithIndex: row];
    else
        indexes = [NSIndexSet indexSet];
    [_outline selectRowIndexes: indexes byExtendingSelection: NO];
    [self enablePropertyButtons];
}


- (JSONItem*) selectedOrClickedProperty {
    NSInteger row = _outline.clickedRow;
    if (row < 0)
        row = _outline.selectedRow;
    return row >= 0 ? [_outline itemAtRow: row] : nil;
}


- (BOOL) saveDocument {
    NSDictionary* properties = _root.value;
    if (!_readOnly && _root && ![properties isEqual: _revision.properties]) {
        CBLDocument* doc;
        NSError* error;
        if (_revision.document)
            doc = _revision.document;
        else
            doc = _db[properties[@"_id"]];
        if (![doc putProperties: _root.value error: &error]) {
            [_outline presentError: error];
            return NO;
        }
        self.revision = doc.currentRevision;
    }
    _saveButton.hidden = _revertButton.hidden = YES;
    return YES;
}


- (IBAction) saveDocument: (id)sender {
    [self saveDocument];
}


- (IBAction) revertDocumentToSaved:(id)sender {
    NSArray* selectedPath = self.selectedProperty.path;
    [self rebuildTable];
    self.selectedProperty = [_root itemAtPath: selectedPath];
    _saveButton.hidden = _revertButton.hidden = !_untitled;
}


#pragma mark - ACTIONS:


- (IBAction) addProperty: (id)sender {
    JSONItem* sibling = self.selectedProperty;
    JSONItem* parent;
    if (sibling == nil) {
        parent = _root;
    } else if ([_outline isItemExpanded: sibling]) {
        parent = sibling;
        sibling = parent.children.firstObject;
    } else {
        parent = sibling.parent;
    }
    
    JSONItem *newItem = [parent createChildBefore: sibling];
    if (!newItem) {
        NSBeep();
        return;
    }
    self.selectedProperty = newItem;
    [self reloadItem: parent];
    [_outline editColumn: (parent.isArray ? 1 : 0)
                     row: [_outline rowForItem: newItem]
               withEvent: nil
                  select: YES];
    _saveButton.hidden = _revertButton.hidden = NO;
}


- (IBAction) removeProperty: (id)sender {
    JSONItem* prop = self.selectedOrClickedProperty;
    if (_readOnly || !prop || prop.isSpecial) {
        NSBeep();
        return;
    }
    JSONItem* parent = prop.parent;
    [parent removeChild: prop];
    [self reloadItem: parent];
    _saveButton.hidden = _revertButton.hidden = NO;
}


- (IBAction) addColumnForSelectedProperty:(id)sender {
    NSArray* property = self.selectedOrClickedProperty.path;
    if (!property)
        return;
    if ([_dbWindowController hasColumnForProperty: property])
        [_dbWindowController removeColumnForProperty: property];
    else
        [_dbWindowController addColumnForProperty: property];
    [self enablePropertyButtons];
}


- (IBAction) cancelOperation: (id)sender {
    if (_outline.editedRow >= 0) {
        _cancelingEdit = YES;
        @try {
            [_outline editColumn: -1 row: -1 withEvent: nil select: NO];
        } @finally {
            _cancelingEdit = NO;
        }
        [_outline reloadData];
    }
}


- (IBAction) copy: (id)sender {
    JSONItem* prop = self.selectedProperty;
    if (!prop) {
        NSBeep();
        return;
    }
    id value = prop.value;
    NSString* json = [JSONFormatter stringForObjectValue: value];
    
    NSPasteboard* pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString: json forType: NSStringPboardType];
}


- (BOOL) validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>)item {
    JSONItem* jsonItem = self.selectedOrClickedProperty;
    SEL action = [item action];
    if (action == @selector(addColumnForSelectedProperty:)) {
        NSArray* property = jsonItem.path;
        NSString* title;
        if (property && [_dbWindowController hasColumnForProperty: property])
            title = @"Remove Column";
        else
            title = @"Add Column";
        [(id)item setTitle: title];
        return (property != nil);
    } else if (action == @selector(removeProperty:)) {
        return (!_readOnly && jsonItem != nil && !jsonItem.isSpecial);
    }
    return YES;
}

- (void) enablePropertyButtons {
    JSONItem* selectedProperty = self.selectedProperty;
    BOOL canInsert = !_readOnly && (_revision != nil || _untitled);
    BOOL canRemove = !_readOnly && selectedProperty && !selectedProperty.isSpecial;
    _addPropertyButton.enabled = canInsert;
    _removePropertyButton.enabled = canRemove;
}


#pragma mark - OUTLINE VIEW DATA SOURCE / DELEGATE:


- (id) outlineView: (NSOutlineView *)outlineView
objectValueForTableColumn: (NSTableColumn *)tableColumn
            byItem: (JSONItem*)item
{
    if ([tableColumn.identifier isEqualToString: @"key"]) {
        return item.key;
    } else {
        if ([outlineView isItemExpanded: item])
            return nil;
        else
            return item.value;
    }
}

- (BOOL) outlineView: (NSOutlineView *)outlineView isItemExpandable: (JSONItem*)item {
    return item == nil || item.children != nil;
}

- (NSInteger) outlineView: (NSOutlineView *)outlineView numberOfChildrenOfItem: (JSONItem*)item {
    item = item ?: _root;
    return item.children.count;
}

- (id) outlineView: (NSOutlineView *)outlineView child: (NSInteger)index ofItem: (JSONItem*)item {
    item = item ?: _root;
    return item.children[index];
}


- (void)outlineView: (NSOutlineView *)outlineView
    willDisplayCell: (NSTextFieldCell*)cell
     forTableColumn: (NSTableColumn *)tableColumn
               item: (JSONItem*)item
{
    BOOL isKeyColumn = [tableColumn.identifier isEqualToString: @"key"];
    NSColor* color;
    if (!item.isSpecial || (_untitled && !isKeyColumn && [item.key isEqual: @"_id"]))
        color = [NSColor controlTextColor];
    else
        color = [NSColor disabledControlTextColor];
    [cell setTextColor: color];
}



- (BOOL)outlineView:(NSOutlineView *)outlineView
shouldEditTableColumn:(NSTableColumn *)tableColumn
               item: (JSONItem*)item
{
    BOOL isKeyColumn = [tableColumn.identifier isEqualToString: @"key"];
    if (_readOnly)
        return NO;
    if (isKeyColumn && item.parent.isArray)
        return NO;
    if (!isKeyColumn && [outlineView isItemExpanded: item])
        return NO;
    if (item.isSpecial) {
        if (isKeyColumn)
            return NO;
        // You can edit the value of the _id property, in an untitled document:
        if (!(_untitled && [item.key isEqualToString: @"_id"]))
            return NO;
    }
    if (isKeyColumn)
        _keyFormatter.item = item;
    _editErrorCount = 0;
    return YES;
}


- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item {
    // Don't expand a (dict/array) item whose JSON is being edited inline:
    return [outlineView rowForItem: item] != [outlineView editedRow];
}


- (void) outlineView: (NSOutlineView*)outlineView
      setObjectValue: (id)newCellValue
      forTableColumn: (NSTableColumn *)tableColumn
              byItem: (JSONItem*)item
{
    if (_cancelingEdit)
        return;
    if (item.isSpecial && !_untitled)
        return;
    
    if (newCellValue == nil || [newCellValue isEqual: @""]) {
        // User entered empty key or value: delete property
        JSONItem* parent = item.parent;
        [parent removeChild: item];
        [self reloadItem: parent];
    } else if ([tableColumn.identifier isEqualToString: @"key"]) {
        item.key = newCellValue;
        //TODO: Re-sort item
    } else {
        item.value = newCellValue;
        [self reloadItem: item]; // expandability may have changed
    }
    _saveButton.hidden = _revertButton.hidden = NO;
}


- (BOOL) control: (NSControl*)control
didFailToFormatString: (NSString*)string
errorDescription: (NSString*)errorMessage
{
    if (_cancelingEdit)
        return YES;
    NSBeep();
    if (++_editErrorCount >= 2) {
        NSAlert* alert = [NSAlert new];
        alert.messageText = @"Invalid JSON in property value";
        alert.informativeText = errorMessage;
        [alert addButtonWithTitle: @"Continue"];
        [alert addButtonWithTitle: @"Cancel"];
        [alert beginSheetModalForWindow: control.window
                      completionHandler:^(NSModalResponse returnCode) {
                          if (returnCode == NSAlertSecondButtonReturn)
                              [self cancelOperation: self];
                      }];
    }
    return NO;
}


- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    [self enablePropertyButtons];
}


- (BOOL)control:(NSControl *)control
       textView:(NSTextView *)textView
doCommandBySelector:(SEL)command
{
    //NSLog(@"command: %@", NSStringFromSelector(command));
    if (command == @selector(cancelOperation:)) {       // Esc key
        [self cancelOperation: self];
        return YES;
    }
    return NO;
}


@end
