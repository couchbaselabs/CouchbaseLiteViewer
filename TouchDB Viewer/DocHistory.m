//
//  DocHistory.m
//  TouchDB Viewer
//
//  Created by Jens Alfke on 8/29/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "DocHistory.h"


NSTreeNode* GetDocRevisionTree(CouchDocument* doc) {
    NSArray* leaves = [doc getConflictingRevisions];
    if (!leaves)
        return nil;
    NSTreeNode* root = [NSTreeNode treeNodeWithRepresentedObject: nil];
    NSMutableDictionary* nodes = [NSMutableDictionary dictionary];
    for (CouchRevision* leaf in leaves) {
        // Get history of this leaf/conflict:
        RESTOperation* op = [leaf sendHTTP: @"GET" parameters: @{@"?revs": @"true"}];
        if (![op wait])
            return nil;
        NSTreeNode* node = nil;
        NSTreeNode* child = nil;
        NSDictionary* revisionsDict = op.responseBody.fromJSON[@"_revisions"];
        int generation = [revisionsDict[@"start"] intValue];
        for (NSString* suffix in revisionsDict[@"ids"]) {
            // Create a rev and a tree node:
            NSString* revID = [NSString stringWithFormat: @"%d-%@", generation, suffix];
            node = nodes[revID];
            BOOL exists = (node != nil);
            if (!exists) {
                CouchRevision* rev = [doc revisionWithID: revID];
                node = [NSTreeNode treeNodeWithRepresentedObject: rev];
                nodes[revID] = node;
            }
            // Add to the tree:
            if (child)
                [node.mutableChildNodes addObject: child];
            child = node;
            --generation;
            if (exists) {
                node = nil;
                break;
            }
        }
        if (node)
            [root.mutableChildNodes addObject: node];
    }
    return root;
}


static void dumpTree(NSTreeNode* node, int indent, NSMutableString* output) {
    for (int i = 0; i < indent; ++i)
        [output appendString: @"    "];
    CouchRevision* rev = node.representedObject;
    [output appendFormat: @"%@%@\n", rev.revisionID, (rev.isDeleted ? @" DEL" : @"")];
    for (NSTreeNode* child in node.childNodes)
        dumpTree(child, indent+1, output);
}


NSString* DumpDocRevisionTree(NSTreeNode* root) {
    NSMutableString* output = [NSMutableString string];
    dumpTree(root, 0, output);
    return output;
}