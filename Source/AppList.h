//
//  AppList.h
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 9/25/13.
//  Copyright (c) 2013 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef enum AppListNodeType {
    kOSNode,
    kAppNode,
    kDbNode
} AppListNodeType;


/** Model for a tree node in the AppListController's outline view */
@interface AppListNode : NSObject

@property (readonly) AppListNodeType type;
@property BOOL isMacOS;
@property (copy) NSString* bundleID;
@property (readonly, nonatomic) NSString* displayName;
@property (readonly, nonatomic) NSString* path;
@property (readonly) NSImage* icon;
@property (readonly) NSArray* nameAndIcon;

@property (readonly) NSMutableArray* children;

@end


AppListNode* BuildAppList(NSError** outError);
void TestAppList(void);
