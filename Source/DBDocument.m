//
//  DBDocument.m
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 4/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "DBDocument.h"
#import "DBWindowController.h"


@implementation DBDocument
{
    @private
    NSString* _path;
    CBLManager* _manager;
    CBLDatabase* _db;
}


- (void) makeWindowControllers {
    DBWindowController* controller = [[DBWindowController alloc] initWithDatabase: _db
                                                                           atPath: _path];
    [self addWindowController: controller];
}

                                      
- (BOOL)readFromURL:(NSURL *)absoluteURL
             ofType:(NSString *)typeName
              error:(NSError **)outError
{
    NSParameterAssert(absoluteURL.isFileURL);
    _path = absoluteURL.path;
    if (![absoluteURL isFileURL] || ![@[@"cblite", @"touchdb"] containsObject: _path.pathExtension]) {
        if (outError)
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain code: -1 userInfo: nil]; //TODO: Real error
        return NO;
    }
    
    NSString* serverPath = _path.stringByDeletingLastPathComponent;
    CBLManagerOptions options = {.readOnly = false, .noReplicator = true};
    NSError* error;
    _manager = [[CBLManager alloc] initWithDirectory: serverPath
                                             options: &options
                                               error: &error];
    if (!_manager) {
        if (outError) *outError = error;
        return NO;
    }
    _db = [_manager databaseNamed: _path.lastPathComponent.stringByDeletingPathExtension
                           error: &error];
    if (!_db) {
        if (outError) *outError = error;
        return NO;
    }
    return YES;
}


- (void) close {
    [_manager close];
    [super close];
}


@end
