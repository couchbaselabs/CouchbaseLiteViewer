//
//  JSONKeyFormatter.m
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 10/21/15.
//  Copyright © 2015 Couchbase, Inc. All rights reserved.
//

#import "JSONKeyFormatter.h"
#import "JSONItem.h"


@implementation JSONKeyFormatter

@synthesize item=_item;


- (BOOL) otherItemHasKey: (NSString*)key {
    JSONItem* otherItem = _item.parent[key];
    return otherItem && otherItem != _item;
}


- (NSString *)stringForObjectValue: (id)obj {
    return [obj description];
}


- (BOOL)getObjectValue:(out id *)obj
             forString:(NSString *)string
      errorDescription:(out NSString **)errorMessage
{
    if (string.length == 0) {
        *obj = nil;
        return YES;
    } else if ([string hasPrefix: @"_"] && _item.parent.isRoot) {
        if (errorMessage)
            *errorMessage = @"Top-level properties may not start with an underscore ('_').";
        return NO;
    } else if ([self otherItemHasKey: string]) {
        if (errorMessage)
            *errorMessage = @"That key already exists.";
        return NO;
    } else {
        *obj = string;
        return YES;
    }
    //TODO: Support numeric keys (for arrays)
}

@end
