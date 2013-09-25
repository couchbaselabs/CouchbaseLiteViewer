//
//  AppList.m
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 9/25/13.
//  Copyright (c) 2013 Couchbase, Inc. All rights reserved.
//

#import "AppList.h"


#define kSimulatorAppID @"com.apple.iphonesimulator"
#define kIconSize 22

static NSString* getAppBundleName(NSString* appHomeDir);


@implementation AppListNode
{
    AppListNodeType _type;
    NSString* _displayName;
    NSString* _path;
    NSMutableArray* _children;
    NSImage* _appIcon;
}


NSImage* kOSIcon, *kAppIcon, *kDbIcon;


+ (void) initialize {
    if (self == [AppListNode class]) {
        NSString* simulatorPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier: kSimulatorAppID];
        kOSIcon = [[[NSWorkspace sharedWorkspace] iconForFile: simulatorPath] copy];
        kOSIcon.size = NSMakeSize(kIconSize, kIconSize);

        kAppIcon = [[NSImage imageNamed: @"ios_app.png"] copy];
        kAppIcon.size = NSMakeSize(kIconSize, kIconSize);

        kDbIcon = [[NSImage imageNamed: @"database.icns"] copy];
        kDbIcon.size = NSMakeSize(kIconSize, kIconSize);
    }
}

@synthesize type=_type, path=_path, displayName=_displayName, children=_children;

- (id) initWithType: (AppListNodeType)type path: (NSString*)path displayName: (NSString*)displayName {
    self = [super init];
    if (self) {
        _type = type;
        _displayName = displayName.copy;
        _path = path.copy;
        _children = [NSMutableArray array];
    }
    return self;
}

- (NSImage*) icon {
    switch (_type) {
        case kOSNode:
            return kOSIcon;
        case kAppNode:
            if (!_appIcon)
                _appIcon = [self findAppIcon] ?: kAppIcon;
            return _appIcon;
        case kDbNode:
            return kDbIcon;
    }
}

- (NSArray*) nameAndIcon {
    return @[self.displayName, self.icon];
}

- (NSImage*) findAppIcon {
    NSString* bundlePath = [self.path stringByAppendingPathComponent: getAppBundleName(self.path)];
    NSString* infoPath = [bundlePath stringByAppendingPathComponent: @"Info.plist"];
    NSDictionary* plist = [NSDictionary dictionaryWithContentsOfFile: infoPath];
    NSString* iconFileName = plist[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"][0];
    if (!iconFileName)
        return nil;
    NSString* iconPath = [bundlePath stringByAppendingPathComponent: iconFileName];
    NSImage* icon = [[NSImage alloc] initByReferencingFile: iconPath];
    icon.size = NSMakeSize(kIconSize, kIconSize);
    return icon;
}

@end


#define kSimulatorPath @"Library/Application Support/iPhone Simulator/"
#define kDbDirName @"CouchbaseLite"
#define kIOSDbDirPath @"Library/Application Support/CouchbaseLite"
#define kDbPathExtensions @[@"cblite", @"touchdb"]
#define kReplicatorDbName @"_replicator"


// Returns a dictionary mapping display-names -> absolute paths.
// Block is given an filename and returns a display-name or nil.
static NSDictionary* iterateDir(NSString* dir, NSError** outError,
                                NSString* (^block)(NSString* filename))
{
    NSArray* filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: dir
                                                                         error: outError];
    if (!filenames)
        return nil;

    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    for (NSString* filename in filenames) {
        NSString* key = block(filename);
        if (key)
            result[key] = [dir stringByAppendingPathComponent: filename];
    }
    return result;
}


static NSDictionary* findIOSSimulatorDirs(NSError** error) {
    NSString* dir = [NSHomeDirectory() stringByAppendingPathComponent: kSimulatorPath];
    return iterateDir(dir, error, ^NSString *(NSString *dirname) {
        if (isdigit([dirname characterAtIndex: 0]) && [dirname doubleValue] >= 6.0)
            return [NSString stringWithFormat: @"iOS %@", dirname];
        return nil;
    });
}


static NSString* getAppBundleName(NSString* appHomeDir) {
    NSArray* appBundles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: appHomeDir
                                                                              error: NULL];
    appBundles = [appBundles pathsMatchingExtensions: @[@"app"]];
    return appBundles.count > 0 ? appBundles[0] : nil;
}


static NSDictionary* findAppDirs(NSString* osDir, NSError** error) {
    NSString* appsDir = [osDir stringByAppendingPathComponent: @"Applications"];
    return iterateDir(appsDir, error, ^NSString *(NSString *dirName) {
        NSString* appHomeDir = [appsDir stringByAppendingPathComponent: dirName];
        NSString* cblPath = [appHomeDir stringByAppendingPathComponent: kIOSDbDirPath];
        if (![[NSFileManager defaultManager] fileExistsAtPath: cblPath])
            return nil;
        return [getAppBundleName(appHomeDir) stringByDeletingPathExtension];
    });
}


static NSDictionary* findAppDatabases(NSString* appHomeDir, NSError** error) {
    NSString* cblPath = [appHomeDir stringByAppendingPathComponent: kIOSDbDirPath];
    return iterateDir(cblPath, error, ^NSString *(NSString *filename) {
        if (![kDbPathExtensions containsObject: filename.pathExtension])
            return nil;
        NSString* dbName = filename.stringByDeletingPathExtension;
        if ([dbName isEqualToString: kReplicatorDbName])
            return nil;
        return [dbName stringByReplacingOccurrencesOfString: @":" withString: @"/"];
    });
}


static NSDictionary* findMacAppDirs(NSError** error) {
    NSString* dirName = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)[0];
    return iterateDir(dirName, error, ^NSString *(NSString *appDirName) {
        NSString* appDirPath = [dirName stringByAppendingPathComponent: appDirName];
        NSString* cblPath = [appDirPath stringByAppendingPathComponent: kDbDirName];
        BOOL isDir;
        if (![[NSFileManager defaultManager] fileExistsAtPath: cblPath isDirectory: &isDir]
                || !isDir)
            return nil;
        return [[appDirName componentsSeparatedByString: @"."] lastObject];
    });
}


static NSDictionary* findMacAppDatabases(NSString* appSupportDir, NSError** error) {
    NSLog(@"Looking in %@", appSupportDir);
    NSString* cblPath = [appSupportDir stringByAppendingPathComponent: kDbDirName];
    return iterateDir(cblPath, error, ^NSString *(NSString *filename) {
        if (![kDbPathExtensions containsObject: filename.pathExtension])
            return nil;
        NSString* dbName = filename.stringByDeletingPathExtension;
        if ([dbName isEqualToString: kReplicatorDbName])
            return nil;
        return [dbName stringByReplacingOccurrencesOfString: @":" withString: @"/"];
    });
}


static NSArray* sortedKeys(NSDictionary* dict) {
    return [dict.allKeys sortedArrayUsingSelector: @selector(localizedCaseInsensitiveCompare:)];
}


AppListNode* BuildAppList(NSError** outError) {
    AppListNode* root = [[AppListNode alloc] initWithType: kOSNode path: nil displayName: nil];
    NSDictionary* versions = findIOSSimulatorDirs(outError);
    if (!versions)
        return nil;
    for (NSString* version in sortedKeys(versions)) {
        AppListNode* versNode = [[AppListNode alloc] initWithType: kOSNode path: versions[version] displayName: version];

        NSDictionary* apps = findAppDirs(versions[version],  outError);
        if (!apps)
            return nil;
        for (NSString* app in sortedKeys(apps)) {
            AppListNode* appNode = [[AppListNode alloc] initWithType: kAppNode path: apps[app] displayName: app];

            NSDictionary* dbs = findAppDatabases(apps[app],  outError);
            if (!dbs)
                return nil;
            for (NSString* db in sortedKeys(dbs)) {
                AppListNode* dbNode = [[AppListNode alloc] initWithType: kDbNode path: dbs[db] displayName: db];
                [appNode.children addObject: dbNode];
            }
            if (appNode.children.count > 0)
                [versNode.children addObject: appNode];
        }
        if (versNode.children.count > 0)
            [root.children addObject: versNode];
    }

    // Now find Mac apps:
    AppListNode* versNode = [[AppListNode alloc] initWithType: kOSNode path: @"" displayName: @"Mac OS"];
    NSDictionary* apps = findMacAppDirs(outError);
    if (!apps)
        return nil;
    for (NSString* app in sortedKeys(apps)) {
        AppListNode* appNode = [[AppListNode alloc] initWithType: kAppNode path: apps[app] displayName: app];

        NSDictionary* dbs = findMacAppDatabases(apps[app],  outError);
        if (!dbs)
            return nil;
        for (NSString* db in sortedKeys(dbs)) {
            AppListNode* dbNode = [[AppListNode alloc] initWithType: kDbNode path: dbs[db] displayName: db];
            [appNode.children addObject: dbNode];
        }
        if (appNode.children.count > 0)
            [versNode.children addObject: appNode];
    }
    if (versNode.children.count > 0)
        [root.children addObject: versNode];

    return root;
}


void TestAppList(void) {
    NSError* error;
    NSDictionary* versions = findIOSSimulatorDirs(&error);
    NSCAssert(versions, @"error %@", error);
    for (NSString* version in sortedKeys(versions)) {
        NSLog(@"%@:", version);
        NSDictionary* apps = findAppDirs(versions[version],  &error);
        NSCAssert(apps, @"error %@", error);
        for (NSString* app in sortedKeys(apps)) {
            NSLog(@"\t%@:", app);
            NSDictionary* dbs = findAppDatabases(apps[app],  &error);
            NSCAssert(dbs, @"error %@", error);
            for (NSString* db in sortedKeys(dbs)) {
                NSLog(@"\t\t%@", db);
            }
        }
    }
}
