//
//  JSONFormatter.h
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 5/4/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JSONFormatter : NSFormatter

+ (NSString*) stringForObjectValue: (id)obj;

@end
