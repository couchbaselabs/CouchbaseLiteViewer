//
//  DBDocument.m
//  TouchDB Viewer
//
//  Created by Jens Alfke on 4/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "DBDocument.h"
#import "DBWindowController.h"
#import <TouchDB/TD_DatabaseManager.h>


@implementation DBDocument
{
    @private
    NSString* _path;
    CouchDatabase* _db;
}


- (void) makeWindowControllers {
    DBWindowController* controller = [[DBWindowController alloc] initWithDatabase: _db];
    [self addWindowController: controller];
}

                                      
- (BOOL)readFromURL:(NSURL *)absoluteURL
             ofType:(NSString *)typeName
              error:(NSError **)outError
{
    NSString* dbPath = absoluteURL.path;
    if (![absoluteURL isFileURL] || ![dbPath.pathExtension isEqualToString: @"touchdb"]) {
        if (outError)
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain code: -1 userInfo: nil]; //TODO: Real error
        return NO;
    }
    
    NSString* serverPath = dbPath.stringByDeletingLastPathComponent;
    TD_DatabaseManagerOptions options = {.readOnly = false, .noReplicator = true};
    CouchTouchDBServer* server = [[CouchTouchDBServer alloc] initWithServerPath: serverPath
                                                                        options: &options];
    if (server.error) {
        if (outError) *outError = server.error;
        return NO;
    }
    _db = [server databaseNamed: dbPath.lastPathComponent.stringByDeletingPathExtension];
    return YES;
}


- (void) close {
    [(CouchTouchDBServer*)_db.server close];
    [super close];
}


@end
