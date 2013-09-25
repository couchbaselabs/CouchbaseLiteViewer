//
//  URLFormatter.m
//  Couchbase Lite Viewer
//
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "URLFormatter.h"


@implementation URLFormatter

@synthesize allowedSchemes=_allowedSchemes;


- (id) init
{
    self = [super init];
    if (self != nil) {
        _allowedSchemes = @[@"http", @"https"];
    }
    return self;
}


// EW: Needed to change implementation to handle relative paths.
// Because this converted an NSURL (from an original string) to a NSString,
// the information about whether the path was relative or not was lost.
// So my changes allow for an NSString to not be converted to a NSURL
// and then I just return the string if that's the case. This string will
// be a relative path like @"../MySource".
- (NSString *)stringForObjectValue:(id)obj
{
    if( [obj isKindOfClass: [NSString class]] )
        return obj;
    else if( ! [obj isKindOfClass: [NSURL class]] )
        return @"";
    else if( [obj isFileURL] )
        return [obj path];
    else
        return [obj absoluteString];
}


- (BOOL)getObjectValue:(id *)obj forString:(NSString *)str errorDescription:(NSString **)outError
{
    *obj = nil;
    NSString *error = nil;
    if( str.length==0 ) {
    } else if( [str hasPrefix: @"/"] ) {
        *obj = [NSURL fileURLWithPath: str];
        if( ! *obj )
            error = @"Invalid filesystem path";
    } else if( [str hasPrefix: @".."] ) {
        /* This check is needed for relative paths, e.g. ../MySource.
           A better implemention should be added to handle relative paths in the middle of the string.
		   Instead of returning an NSURL, I return an NSString because this code gets called by
		   stringForObjectValue which then converts it back to an NSString. The double conversion
		   was causing information to be lost about whether the NSURL was a relative path or not.
        */
        NSString* expanded_string = [str stringByStandardizingPath];
        *obj = expanded_string;
        if( ! *obj )
            error = @"Invalid filesystem path";
    } else {        
        NSURL *url = [NSURL URLWithString: str];
        NSString *scheme = [url scheme];
        if( url && scheme == nil ) {
            if( [str rangeOfString: @"."].length > 0 || [str rangeOfString: @":"].length > 0 ) {
                // Turn "foo.com/bar" into "http://foo.com/bar":
                str = [@"http://" stringByAppendingString: str];
                url = [NSURL URLWithString: str];
                scheme = [url scheme];
            } else
                url = nil;
        }
        if( ! url || ! [url path] || url.host.length==0 ) {
            error = @"Invalid URL";
        } else if( _allowedSchemes && ! [_allowedSchemes containsObject: scheme] ) {
            error = [@"URL protocol must be %@" stringByAppendingString:
                                    [_allowedSchemes componentsJoinedByString: @", "]];
        }
        *obj = url;
    }
    if( outError ) *outError = error;
    return (error==nil);
}


@end
