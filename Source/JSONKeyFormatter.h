//
//  JSONKeyFormatter.h
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 10/21/15.
//  Copyright © 2015 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@class JSONItem;

@interface JSONKeyFormatter : NSFormatter

@property JSONItem* item;

@end
