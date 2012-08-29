//
//  DocEditor.m
//  TouchDB Viewer
//
//  Created by Jens Alfke on 5/4/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "DocEditor.h"
#import "DBWindowController.h"


@implementation DocEditor
{
    CouchDatabase* _db;
    CouchRevision* _revision;
    BOOL _readOnly;
    BOOL _untitled;
    NSDictionary* _originalProperties;
    NSMutableDictionary* _properties;
    NSMutableArray* _propNames;
    BOOL _cancelingEdit;
    
    IBOutlet DBWindowController* _dbWindowController;
    IBOutlet NSTableView* _table;
    IBOutlet NSButton *_addPropertyButton, *_removePropertyButton, *_addColumnButton;
    IBOutlet NSButton *_saveButton, *_revertButton;
}


@synthesize database=_db, tableView=_table, readOnly=_readOnly;


- (void) awakeFromNib {
    NSLayoutConstraint* c = [NSLayoutConstraint constraintWithItem: _addPropertyButton
                                                         attribute: NSLayoutAttributeLeft
                                                         relatedBy: NSLayoutRelationEqual
                                                            toItem: _table
                                                         attribute: NSLayoutAttributeLeft
                                                        multiplier: 1.0 constant: 0];
    [_table.window.contentView addConstraint: c];
}


- (CouchRevision*) revision {
    return _revision;
}

- (void) setRevision: (CouchRevision*)rev {
    if (rev != _revision || _untitled) {
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


static BOOL isSpecialProperty(NSString* key) {
    return [key hasPrefix: @"_"];
}

- (void) rebuildTable {
    _propNames = _properties.allKeys.mutableCopy;
    [self sortProperties];
}

- (void) sortProperties {
    [_propNames sortUsingComparator: ^NSComparisonResult(NSString* key1, NSString* key2) {
        int n = (isSpecialProperty(key1) != 0) - (isSpecialProperty(key2) != 0);
        if (n)
            return n;
        return [key1 caseInsensitiveCompare: key2];
    }];
    [_table reloadData];
}


- (NSString*) selectedProperty {
    NSInteger row = _table.selectedRow;
    return row >= 0 ? [_propNames objectAtIndex: row] : nil;
}


- (void) setSelectedProperty: (NSString*)property {
    NSUInteger row = [_propNames indexOfObject: property];
    NSIndexSet* indexes = nil;
    if (row != NSNotFound)
        indexes = [NSIndexSet indexSetWithIndex: row];
    else
        indexes = [NSIndexSet indexSet];
    [_table selectRowIndexes: indexes byExtendingSelection: NO];
    [self enablePropertyButtons];
}


- (NSString*) selectedOrClickedProperty {
    NSInteger row = _table.clickedRow;
    if (row < 0)
        row = _table.selectedRow;
    return row >= 0 ? [_propNames objectAtIndex: row] : nil;
}


- (BOOL) saveDocument {
    if (!_readOnly && _properties && ![_properties isEqual: _originalProperties]) {
        CouchDocument* doc;
        NSError* error;
        if (_revision)
            doc = _revision.document;
        else
            doc = [_db documentWithID: [_properties objectForKey: @"_id"]];
        if (![[doc putProperties: _properties] wait: &error]) {
            [_table presentError: error];
            return NO;
        }
        self.revision = doc.currentRevision;
        _properties = _revision.properties.mutableCopy;
        _originalProperties = _properties.copy;
    }
    _saveButton.hidden = _revertButton.hidden = YES;
    return YES;
}


- (IBAction) saveDocument: (id)sender {
    [self saveDocument];
}


- (IBAction) revertDocumentToSaved:(id)sender {
    NSString* selectedProperty = self.selectedProperty;
    if (_untitled) {
        NSString* docID = [[_db.server generateUUIDs: 1] lastObject];
        _properties = [NSMutableDictionary dictionaryWithObject: docID forKey: @"_id"];
    } else {
        _properties = _revision.properties.mutableCopy;
    }
    _originalProperties = _properties.copy;
    [self rebuildTable];
    self.selectedProperty = selectedProperty;
    _saveButton.hidden = _revertButton.hidden = !_untitled;
}


#pragma mark - ACTIONS:


- (IBAction) addProperty: (id)sender {
    // Insert a placeholder empty-string property for the user to fill in:
    if (_readOnly || [_propNames containsObject: @""] || [_properties objectForKey: @""]) {
        NSBeep();
        return;
    }
    [_propNames insertObject: @"" atIndex: 0];
    [_table reloadData];
    self.selectedProperty = @"";
    [_table editColumn: 0 row: 0 withEvent: nil select: YES];
}


- (IBAction) removeProperty: (id)sender {
    NSString* prop = self.selectedOrClickedProperty;
    if (_readOnly || !prop || isSpecialProperty(prop)) {
        NSBeep();
        return;
    }
    [_properties removeObjectForKey: prop];
    [self rebuildTable];
}


- (IBAction) addColumnForSelectedProperty:(id)sender {
    NSString* property = self.selectedOrClickedProperty;
    if (!property)
        return;
    if ([_dbWindowController hasColumnForProperty: property])
        [_dbWindowController removeColumnForProperty: property];
    else
        [_dbWindowController addColumnForProperty: property];
    [self enablePropertyButtons];
}


- (IBAction) cancelOperation: (id)sender {
    if ([_table editedRow] >= 0) {
        _cancelingEdit = YES;
        @try {
            [_table editColumn: -1 row: -1 withEvent: nil select: NO];
        } @finally {
            _cancelingEdit = NO;
        }
        [self rebuildTable];
    }
}


- (BOOL) validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>)item {
    NSLog(@"validate %@", item);//TEMP
    NSString* property = self.selectedOrClickedProperty;
    SEL action = [item action];
    if (action == @selector(addColumnForSelectedProperty:)) {
        NSString* title;
        if (property && [_dbWindowController hasColumnForProperty: property])
            title = @"Remove Column";
        else
            title = @"Add Column";
        [(id)item setTitle: title];
        return (property != nil);
    } else if (action == @selector(removeProperty:)) {
        return (!_readOnly && property != nil && !isSpecialProperty(property));
    }
    return YES;
}


- (void) enablePropertyButtons {
    NSString* selectedProperty = self.selectedProperty;
    BOOL canInsert = !_readOnly && (_revision != nil || _untitled);
    BOOL canRemove = !_readOnly && selectedProperty && !isSpecialProperty(selectedProperty);
    _addPropertyButton.enabled = canInsert;
    _removePropertyButton.enabled = canRemove;
    _addColumnButton.enabled = selectedProperty && !isSpecialProperty(selectedProperty);
    _addColumnButton.title = (selectedProperty && [_dbWindowController hasColumnForProperty: selectedProperty]) ? @"Remove Column" : @"Add Column";
}


#pragma mark - TABLE VIEW DATA SOURCE / DELEGATE:


- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _propNames.count;
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(NSInteger)row
{
    id result = [_propNames objectAtIndex: row];
    if (![tableColumn.identifier isEqualToString: @"key"])
        result = [_properties objectForKey: result];
    return result;
}


- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(NSTextFieldCell*)cell
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)row
{
    NSString* key = [_propNames objectAtIndex: row];
    NSColor* color;
    if (isSpecialProperty(key))
        color = [NSColor disabledControlTextColor];
    else
        color = [NSColor controlTextColor];
    [cell setTextColor: color];
}


- (BOOL)tableView:(NSTableView *)tableView 
        shouldEditTableColumn:(NSTableColumn *)tableColumn
        row:(NSInteger)row
{
    if (_readOnly)
        return NO;
    NSString* key = [_propNames objectAtIndex: row];
    if (!isSpecialProperty(key))
        return YES;
    if (_untitled && [key isEqualToString: @"_id"] &&
            ![[tableColumn identifier] isEqualToString: @"key"])
        return YES;
    else
        return NO;
}


- (void)tableView:(NSTableView *)tableView
   setObjectValue:(NSString*)newCellValue
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)row
{
    if (_cancelingEdit)
        return;
    BOOL editingKey = [tableColumn.identifier isEqualToString: @"key"];
    NSString* key = [_propNames objectAtIndex: row];
    if (isSpecialProperty(key) && !_untitled)
        return;
    
    if ([_properties objectForKey: key]) {
        // Yes, this is a real document property:
        if (newCellValue == nil || [newCellValue isEqual: @""]) {
            // User entered empty key or value: delete property
            [_properties removeObjectForKey: key];
            [self rebuildTable];
            
        } else if (editingKey) {
            // Change the key:
            if ([newCellValue isEqualToString: key])
                return; // no-op
            if (isSpecialProperty(newCellValue)) {
                NSBeep();
                return;
            }
            if ([_properties objectForKey: newCellValue]) {
                NSBeep();  // duplicate key!
                return;
            }
            id value = [_properties objectForKey: key];
            [_properties setObject: value forKey: newCellValue];
            [_properties removeObjectForKey: key];
            [self rebuildTable];
            self.selectedProperty = newCellValue;
            
        } else {
            // Change the value:
            if ([newCellValue isEqual: [_properties objectForKey: key]])
                return; // no-op
            [_properties setObject: newCellValue forKey: key];
        }
        
    } else {
        // Editing the fake row inserted by addProperty:
        if (newCellValue == nil || [newCellValue isEqual: @""]) {
            // User entered empty key or value; delete property
            [_propNames removeObjectAtIndex: row];
            [self rebuildTable];
            self.selectedProperty = nil;
            
        } else if (editingKey) {
            // Changing the key, so re-sort:
            if (isSpecialProperty(newCellValue)) {
                NSBeep();
                return;
            }
            if ([_properties objectForKey: newCellValue]) {
                NSBeep();  // duplicate key!
                return;
            }
            [_propNames replaceObjectAtIndex: row withObject: newCellValue];
            [self sortProperties];
            self.selectedProperty = newCellValue;
        } else {
            // Changing the value:
            [_properties setObject: newCellValue forKey: key];
        }
    }
    
    _saveButton.hidden = _revertButton.hidden = NO;
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification {
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
