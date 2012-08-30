//
//  DocHistory.m
//  TouchDB Viewer
//
//  Created by Jens Alfke on 8/29/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "DocHistory.h"


NSTreeNode* SortRevisionTree(NSTreeNode* tree) {
    [tree.mutableChildNodes sortUsingComparator: ^NSComparisonResult(id obj1, id obj2) {
        CouchRevision* rev1 = [obj1 representedObject];
        CouchRevision* rev2 = [obj2 representedObject];
        // Plain string compare is OK because sibling revs must start with the same gen #.
        // Comparing backwards because we want descending rev IDs, i.e. winner first.
        return [rev2.revisionID compare: rev1.revisionID];
    }];
    for (NSTreeNode* child in tree.childNodes)
        SortRevisionTree(child);
    return tree;
}


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
    SortRevisionTree(root);
    return root;
}


static void addLeafNodes(NSTreeNode* node, NSMutableSet* leaves) {
    if (node.isLeaf)
        [leaves addObject: node];
    else {
        for (NSTreeNode* child in node.childNodes)
            addLeafNodes(child, leaves);
    }
}


NSSet* GetLeafNodes(NSTreeNode* tree) {
    NSMutableSet* leaves = [NSMutableSet set];
    addLeafNodes(tree, leaves);
    return leaves;
}


NSTreeNode* FlattenTree(NSTreeNode* root) {
    // If this node has one child, make its linear decendent chain into direct children:
    if (root.childNodes.count == 1) {
        NSTreeNode* child = root;
        while (!child.isLeaf) {
            NSTreeNode* parent = child;
            child = child.childNodes[0];
            [parent.mutableChildNodes removeObject: child];
            [root.mutableChildNodes addObject: child];
        }
    }
    // Now recurse:
    for (NSTreeNode* child in root.childNodes)
        FlattenTree(child);
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