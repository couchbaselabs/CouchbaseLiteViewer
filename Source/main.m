//
//  main.m
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 4/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern void TestAppList(void);//TEMP

int main(int argc, char *argv[])
{
#if 0
    TestAppList();
    return 0;
#else
    return NSApplicationMain(argc, (const char **)argv);
#endif
}
