//
//  JSONFormatter.m
//  TouchDB Viewer
//
//  Created by Jens Alfke on 5/4/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "JSONFormatter.h"

@implementation JSONFormatter


+ (NSString*) stringForObjectValue: (id)obj {
    if (obj == nil)
        return @"";
    NSArray* wrapped = @[obj]; // in case obj is a fragment
    NSData* data = [NSJSONSerialization dataWithJSONObject: wrapped options: 0 error: nil];
    data = [data subdataWithRange: NSMakeRange(1, data.length - 2)];
    return [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
}


- (NSString *)stringForObjectValue: (id)obj {
    return [[self class] stringForObjectValue: obj];
}


- (BOOL)getObjectValue:(out id *)obj
             forString:(NSString *)string
      errorDescription:(out NSString **)errorMessage
{
    if (string.length == 0) {
        // Empty string becomes a true nil value (as opposed to NSNull)
        *obj = nil;
        return YES;
    }
    NSData* data = [string dataUsingEncoding: NSUTF8StringEncoding];
    NSError* error;
    *obj = [NSJSONSerialization JSONObjectWithData: data
                                           options: NSJSONReadingAllowFragments
                                             error: &error];
    if (*obj) {
        return YES;
    } else {
        if (errorMessage)
            *errorMessage = error.localizedDescription;
        return NO;
    }
}


@end
