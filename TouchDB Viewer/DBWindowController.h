//
//  DBWindowController.h
//  TouchDB Viewer
//
//  Created by Jens Alfke on 4/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class CouchDatabase;


@interface DBWindowController : NSWindowController

- (id)initWithDatabase: (CouchDatabase*)db;

@end
