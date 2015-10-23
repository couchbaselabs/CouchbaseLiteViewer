//
//  JSONItem.h
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 10/20/15.
//  Copyright © 2015 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JSONItem : NSObject

- (instancetype) initWithValue: (id)value;

@property (copy, nonatomic) id value;
@property (copy, nonatomic) id key;

@property (readonly, nonatomic) NSArray<JSONItem*>* children;
@property (readonly, nonatomic, weak) JSONItem* parent;

@property (readonly) BOOL isRoot;
@property (readonly) BOOL isSpecial;
@property (readonly) BOOL isArray;
@property (readonly) BOOL isDictionary;
@property (readonly) BOOL isKeyEditable;

- (JSONItem*) objectAtIndexedSubscript: (NSUInteger)index;
- (JSONItem*) objectForKeyedSubscript: (id)key;

@property (readonly) NSArray* path;
- (JSONItem*) itemAtPath: (NSArray*)path;

+ (id) itemAtPath: (NSArray*)path inObject: (id)value;

- (JSONItem*) createChildBefore: (JSONItem*)sibling;
- (BOOL) removeChild: (JSONItem*)child;

@end


