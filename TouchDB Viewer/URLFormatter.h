//
//  URLFormatter.h
//  TouchDB Viewer
//
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


/** An NSFormatter for NSURL objects.
    It formats a file: URL as a plain path, other URLs in absolute form, and nil as an empty string.
    It intelligently parses user-entered URLs, turning absolute paths into file: URLs,
    or adding a missing "http" prefix if necessary.
    It also allows you to pop up a file picker, whose result will be entered as a path. */
@interface URLFormatter : NSFormatter
{
    NSArray *_allowedSchemes;
}

@property (copy,nonatomic) NSArray *allowedSchemes;

@end
