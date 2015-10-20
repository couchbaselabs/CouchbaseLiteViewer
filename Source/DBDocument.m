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


#define kPollInterval 2.0


@implementation DBDocument
{
    @private
    NSString* _path;
    CBLManager* _manager;
    CBLDatabase* _db;
    NSTimer* _pollTimer;
    uint64_t _lastSequence;
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
    BOOL isNewFormat = [extension isEqualToString: @"cblite2"];

    if (CBLVersion().doubleValue >= 1.2) {
        // If we have Couchbase Lite 1.2 we shouldn't open an old-format database because it'll be
        // upgraded to the new format, and that might make it unreadable in its host app:
        if (!isNewFormat) {
            return returnErrorWithMessage(@"This database is too old to be opened by this app. Its host app needs to be upgraded to 1.2 format first.", outError);
        }
    } else {
        if (isNewFormat) {
            return returnErrorWithMessage(@"This database is too new to be opened by this app. Use a Viewer that supports Couchbase Lite 1.2.", outError);
        }
    }

    CBLManagerOptions options = {.readOnly = false};
    NSString* managerPath = _path.stringByDeletingLastPathComponent;
    NSError* error;
    _manager = [[CBLManager alloc] initWithDirectory: managerPath
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

    // Set up polling of lastSequence to detect external changes:
    _lastSequence = _db.lastSequenceNumber;
    NSLog(@"Database lastSequence = %llu", _lastSequence);
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(dbChanged:)
                                                 name: kCBLDatabaseChangeNotification object: _db];
    _pollTimer = [NSTimer scheduledTimerWithTimeInterval: kPollInterval
                                                  target: self selector: @selector(checkForChanges:)
                                                userInfo: nil repeats: YES];
    return YES;
}


- (void) close {
    [_pollTimer invalidate];
    _pollTimer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: kCBLDatabaseChangeNotification
                                                  object: _db];
    [_manager close];
    [super close];
}


- (void) checkForChanges: (NSTimer*)timer {
    uint64_t seq = _db.lastSequenceNumber;
    if (seq > _lastSequence) {
        NSLog(@"Detected external database change! (%llu)", seq);
        [[NSNotificationCenter defaultCenter] postNotificationName: kCBLDatabaseChangeNotification
                                                            object: _db];
    }
}


- (void) dbChanged: (NSNotification*)n {
    _lastSequence = _db.lastSequenceNumber;
    NSLog(@"Database changed (%llu)", _lastSequence);
}


@end
