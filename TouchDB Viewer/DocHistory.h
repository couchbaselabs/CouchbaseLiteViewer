//
//  DocHistory.h
//  TouchDB Viewer
//
//  Created by Jens Alfke on 8/29/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NSTreeNode* GetDocRevisionTree(CouchDocument* doc);

NSSet* GetLeafNodes(NSTreeNode* tree);

NSTreeNode* CopyTree(NSTreeNode* root);

void FlattenTree(NSTreeNode* root);

NSTreeNode* TreeWithoutDeletedBranches(NSTreeNode* root);

NSString* DumpDocRevisionTree(NSTreeNode* root);
