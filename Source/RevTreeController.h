//
//  RevTreeController.h
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 8/29/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RevTreeController : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate>

@property (weak) NSOutlineView* outline;
@property (strong) CBLDocument* document;
@property BOOL showDeleted;

@end
