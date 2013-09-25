//
//  DocHistory.m
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 8/29/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "DocHistory.h"


NSTreeNode* SortRevisionTree(NSTreeNode* tree) {
    [tree.mutableChildNodes sortUsingComparator: ^NSComparisonResult(id obj1, id obj2) {
        CBLRevision* rev1 = [obj1 representedObject];
        CBLRevision* rev2 = [obj2 representedObject];
        // Plain string compare is OK because sibling revs must start with the same gen #.
        // Comparing backwards because we want descending rev IDs, i.e. winner first.
        return [rev2.revisionID compare: rev1.revisionID];
    }];
    for (NSTreeNode* child in tree.childNodes)
        SortRevisionTree(child);
    return tree;
}


NSTreeNode* GetDocRevisionTree(CBLDocument* doc) {
    NSError* error;
    NSArray* leaves = [doc getLeafRevisions: &error];
    if (!leaves)
        return nil;
    NSTreeNode* root = [NSTreeNode treeNodeWithRepresentedObject: nil];
    NSMutableDictionary* nodes = [NSMutableDictionary dictionary];
    for (CBLRevision* leaf in leaves) {
        // Get history of this leaf/conflict:
        NSArray* history = [leaf getRevisionHistory: &error];
        if (!history)
            return nil;
        NSTreeNode* node = nil;
        NSTreeNode* child = nil;
        for (NSInteger i = (NSInteger)history.count - 1; i >= 0; i--) {
            // Create a rev and a tree node:
            CBLRevision* rev = history[i];
            NSString* revID = rev.revisionID;
            node = nodes[revID];
            BOOL exists = (node != nil);
            if (!exists) {
                node = [NSTreeNode treeNodeWithRepresentedObject: rev];
                nodes[revID] = node;
            }
            // Add to the tree:
            if (child)
                [node.mutableChildNodes addObject: child];
            child = node;
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


NSTreeNode* CopyTree(NSTreeNode* root) {
    if (!root)
        return nil;
    NSTreeNode* copiedRoot = [NSTreeNode treeNodeWithRepresentedObject: root.representedObject];
    for (NSTreeNode* child in root.childNodes)
        [copiedRoot.mutableChildNodes addObject: CopyTree(child)];
    return copiedRoot;
}


void FlattenTree(NSTreeNode* root) {
    if (!root)
        return;
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
}


NSTreeNode* TreeWithoutDeletedBranches(NSTreeNode* root) {
    if (!root)
        return nil;
    CBLRevision* rev = root.representedObject;
    if (root.isLeaf) {
        if (rev.isDeleted)
            return nil;
        return [NSTreeNode treeNodeWithRepresentedObject: rev];
    } else {
        NSMutableArray* children = [NSMutableArray array];
        for (NSTreeNode* child in root.childNodes) {
            NSTreeNode* prunedChild = TreeWithoutDeletedBranches(child);
            if (prunedChild)
                [children addObject: prunedChild];
        }
        if (children.count == 0)
            return nil;
        root = [NSTreeNode treeNodeWithRepresentedObject: rev];
        [root.mutableChildNodes setArray: children];
        return root;
    }
}


static void dumpTree(NSTreeNode* node, int indent, NSMutableString* output) {
    for (int i = 0; i < indent; ++i)
        [output appendString: @"    "];
    CBLRevision* rev = node.representedObject;
    [output appendFormat: @"%@%@\n", rev.revisionID, (rev.isDeleted ? @" DEL" : @"")];
    for (NSTreeNode* child in node.childNodes)
        dumpTree(child, indent+1, output);
}


NSString* DumpDocRevisionTree(NSTreeNode* root) {
    NSMutableString* output = [NSMutableString string];
    dumpTree(root, 0, output);
    return output;
}
