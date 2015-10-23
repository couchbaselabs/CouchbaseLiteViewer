//
//  JSONItem.m
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 10/20/15.
//  Copyright © 2015 Couchbase, Inc. All rights reserved.
//

#import "JSONItem.h"

@implementation JSONItem

@synthesize value=_value, key=_key, children=_children, parent=_parent;

static BOOL isSpecialProperty(NSString* key) {
    return [key hasPrefix: @"_"];
}

- (instancetype) initWithValue: (id)value {
    return [self initWithValue: value key: nil parent: nil];
}

- (instancetype) initWithValue: (id)value key: (id)key parent: (JSONItem*)parent {
    self = [super init];
    if (self) {
        _value = value;
        _key = key;
        _parent = parent;
        [self rebuildChildren];
    }
    return self;
}


- (void) rebuildChildren {
    NSMutableArray* children = nil;
    if ([_value isKindOfClass: [NSArray class]]) {
        children = [NSMutableArray arrayWithCapacity: [_value count]];
        NSUInteger index = 0;
        for (NSObject *child in _value)
            [children addObject: [[JSONItem alloc] initWithValue: child
                                                             key: @(index++)
                                                          parent: self]];
    } else if ([_value isKindOfClass: [NSDictionary class]]) {
        children = [NSMutableArray arrayWithCapacity: [_value count]];
        NSMutableArray* keys = [[_value allKeys] mutableCopy];
        if (_key) {
            [keys sortUsingSelector: @selector(caseInsensitiveCompare:)];
        } else {
            // top level
            [keys sortUsingComparator: ^NSComparisonResult(NSString* key1, NSString* key2) {
                int n = (isSpecialProperty(key2) != 0) - (isSpecialProperty(key1) != 0);
                return n ?: [key1 caseInsensitiveCompare: key2];
            }];
        }
        for (NSObject *key in keys)
            [children addObject: [[JSONItem alloc] initWithValue: [_value objectForKey: key]
                                                             key: key
                                                          parent: self]];
    }
    _children = children;
}


- (JSONItem*) objectAtIndexedSubscript: (NSUInteger)index {
    return _children[index];
}

- (JSONItem*) objectForKeyedSubscript: (id)key {
    if ([key isKindOfClass: [NSNumber class]]) {
        NSInteger index = [key longLongValue];
        if (self.isArray && index >= 0 && index < [_value count])
            return [_children objectAtIndex: index];
    } else if ([key isKindOfClass: [NSString class]]) {
        if (self.isDictionary) {
            for (JSONItem* child in _children)
                if ([child.key isEqual: key])
                    return child;
        }
    }
    return nil;
}

- (BOOL) isRoot {
    return _key == nil;
}

- (BOOL) isSpecial {
    return _parent.isSpecial
        || (_parent.isRoot && [_key isKindOfClass: [NSString class]] && [_key hasPrefix: @"_"]);
}

- (BOOL) isArray {
    return [_value isKindOfClass: [NSArray class]];
}

- (BOOL) isDictionary {
    return [_value isKindOfClass: [NSDictionary class]];
}


- (JSONItem*) createChildBefore: (JSONItem*)sibling {
    if (!self.isArray && !self.isDictionary)
        return nil;
    NSUInteger index = sibling ? [_children indexOfObjectIdenticalTo: sibling] : _children.count;
    if (index == NSNotFound)
        return nil;

    JSONItem* newChild = [[JSONItem alloc] initWithValue: nil
                                                     key: (self.isArray ? @(index) : @"")
                                                  parent: self];

    NSMutableArray* children = [_children mutableCopy];
    [children insertObject: newChild atIndex: index];
    _children = children;
    [self fixupChildren: children from: index];
    [self childChanged];
    return newChild;
}


- (BOOL) removeChild: (JSONItem*)child {
    NSUInteger index = [_children indexOfObjectIdenticalTo: child];
    if (index == NSNotFound)
        return NO;
    NSMutableArray<JSONItem*>* children = _children.mutableCopy;
    [children removeObjectAtIndex: index];
    _children = children;

    [self fixupChildren: children from: index];
    [self childChanged];
    return YES;
}

- (void) fixupChildren: (NSMutableArray<JSONItem*>*)children from: (NSUInteger)index {
    if (self.isArray) {
        // Renumber succeeding children of an array:
        for (; index < children.count; index++)
            children[index]->_key = @(index);
    }
}


- (BOOL) isKeyEditable {
    return [_key isKindOfClass: [NSString class]] && !self.isSpecial;
}


- (void) setValue: (id)value {
    if (value == _value || [value isEqual: _value])
        return;
    _value = [value copy];
    [self rebuildChildren];
    [_parent childChanged];
}

- (void) setKey: (id)key {
    if (key == _key || [key isEqual: _key])
        return;
    NSAssert(self.isKeyEditable, @"Can't change key of %@", self);
    _key = [key copy];
    [_parent childChanged];
    //TODO: Re-sort parent's children
}

- (void) childChanged {
    _value = [self computeValue];
    [_parent childChanged];
}

- (id) computeValue {
    if (self.isArray) {
        NSMutableArray* v = [NSMutableArray arrayWithCapacity: _children.count];
        for (JSONItem* child in _children) {
            if (child.value)
                [v addObject: child.value];
        }
        return v;
    } else if (self.isDictionary) {
        NSMutableDictionary* v = [NSMutableDictionary dictionaryWithCapacity: _children.count];
        for (JSONItem* child in _children) {
            if (child.value)
                [v setObject: child.value forKey: child.key];
        }
        return v;
    } else {
        return _value;
    }
}


- (NSArray*) path {
    NSMutableArray* path = [NSMutableArray array];
    for (JSONItem* item = self; !item.isRoot; item=item.parent)
        [path insertObject: item.key atIndex: 0];
    return path;
}


- (JSONItem*) itemAtPath: (NSArray*)path {
    JSONItem* item = self;
    for (id p in path) {
        item = item[p];
        if (!item)
            break;
    }
    return item;
}


+ (id) itemAtPath: (NSArray*)path inObject: (id)value {
    for (id key in path) {
        if ([key isKindOfClass: [NSNumber class]]) {
            NSInteger index = [key longLongValue];
            if (![value isKindOfClass: [NSArray class]])
                return nil;
            NSUInteger count = [value count];
            if (index < 0)
                index += count;
            if (index < 0 || index >= count)
                return nil;
            value = [value objectAtIndex: index];
        } else {
            if (![value isKindOfClass: [NSDictionary class]])
                return nil;
            value = [value objectForKey: key];
            if (!value)
                return nil;
        }
    }
    return value;
}


@end
