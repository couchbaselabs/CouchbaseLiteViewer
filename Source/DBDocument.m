//
//  DBDocument.m
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 4/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "DBDocument.h"
#import "DBWindowController.h"
#import <CouchbaseLite/CouchbaseLite.h>


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


static BOOL returnErrorWithMessage(NSString* message, NSError **outError) {
    if (outError) {
        NSDictionary* userInfo = @{NSLocalizedFailureReasonErrorKey: message};
        *outError = [NSError errorWithDomain: @"CBLViewer" code: -1 userInfo: userInfo];
    }
    return NO;
}


- (BOOL)readFromURL:(NSURL *)absoluteURL
             ofType:(NSString *)typeName
              error:(NSError **)outError
{
    NSLog(@"Opening %@", absoluteURL.path);
    _path = absoluteURL.path;
    NSString* extension = _path.pathExtension;
    if (![absoluteURL isFileURL] || ![@[@"cblite", @"cblite2"] containsObject: extension]) {
        return returnErrorWithMessage(@"This file format is not supported.", outError);
    }

    BOOL supportsNewFormat = CBLVersion().doubleValue >= 1.2;
    BOOL isNewFormat = [extension isEqualToString: @"cblite2"];
    if (isNewFormat < supportsNewFormat) {
        return returnErrorWithMessage(@"This database is too old to be opened by this app.", outError);
    }

    NSString* serverPath = _path.stringByDeletingLastPathComponent;
    CBLManagerOptions options = {.readOnly = false};
    if (supportsNewFormat && !isNewFormat) {
        NSLog(@"NOTE: Opening old-format database as read-only");
        options.readOnly = YES;
    }
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
