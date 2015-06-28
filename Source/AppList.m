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


NSImage* kiOSIcon, *kMacOSIcon, *kAppIcon, *kMacAppIcon, *kDbIcon;


+ (void) initialize {
    if (self == [AppListNode class]) {
        NSString* simulatorPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier: kSimulatorAppID];
        kiOSIcon = [[[NSWorkspace sharedWorkspace] iconForFile: simulatorPath] copy];
        kiOSIcon.size = NSMakeSize(kIconSize, kIconSize);

        kMacOSIcon = [[[NSWorkspace sharedWorkspace] iconForFile: @"/System/Library/CoreServices/Finder.app"] copy];
        kMacOSIcon.size = NSMakeSize(kIconSize, kIconSize);

        kAppIcon = [[NSImage imageNamed: @"ios_app.png"] copy];
        kAppIcon.size = NSMakeSize(kIconSize, kIconSize);

        kMacAppIcon = [[NSWorkspace sharedWorkspace] iconForFileType: NSFileTypeForHFSTypeCode('APPL')];

        kDbIcon = [[NSImage imageNamed: @"database.icns"] copy];
        kDbIcon.size = NSMakeSize(kIconSize, kIconSize);
    }
}

@synthesize type=_type, path=_path, displayName=_displayName, children=_children;
@synthesize isMacOS=_isMacOS, bundleID=_bundleID;

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
            return _isMacOS ?kMacOSIcon : kiOSIcon;
        case kAppNode:
            if (!_appIcon)
                _appIcon = [self findAppIcon] ?: (_isMacOS ? kMacAppIcon : kAppIcon);
            return _appIcon;
        case kDbNode:
            return kDbIcon;
    }
}

- (NSArray*) nameAndIcon {
    return @[self.displayName, self.icon];
}

- (NSImage*) findAppIcon {
    NSImage* icon = nil;
#if 1
    NSString* appPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier: _bundleID];
    if (appPath)
        icon = [[NSWorkspace sharedWorkspace] iconForFile: appPath];
#else
    NSString* bundlePath = [self.path stringByAppendingPathComponent: getAppBundleName(self.path)];
    NSString* infoPath = [bundlePath stringByAppendingPathComponent: @"Info.plist"];
    NSDictionary* plist = [NSDictionary dictionaryWithContentsOfFile: infoPath];
    NSString* iconFileName = plist[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"][0];
    if (!iconFileName)
        return nil;
    NSString* iconPath = [bundlePath stringByAppendingPathComponent: iconFileName];
    icon = [[NSImage alloc] initByReferencingFile: iconPath];
#endif
    if (!icon)
        icon = (_isMacOS ? kMacAppIcon : kAppIcon);
    icon.size = NSMakeSize(kIconSize, kIconSize);
    return icon;
}

@end


#define kSimulatorPath @"Library/Developer/CoreSimulator/Devices/"
#define kDbDirName @"CouchbaseLite"
#define kIOSDbDirPath @"Library/Application Support/CouchbaseLite"
#define kDbPathExtensions @[@"cblite", @"cblite2"]
#define kReplicatorDbName @"_replicator"    // old persistent-replications database, pre-1.0


// Returns a dictionary mapping display-names -> absolute paths.
// Block is given a filename and returns a display-name or nil.
static NSMutableDictionary* iterateDir(NSString* dir, NSError** outError,
                                       NSString* (^block)(NSString* path, NSString* filename))
{
    NSArray* filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: dir
                                                                             error: outError];
    if (!filenames) {
        if ([[*outError domain] isEqualToString: NSCocoaErrorDomain] && [*outError code] == NSFileReadNoSuchFileError) {
            *outError = nil;
            return [NSMutableDictionary new];
        }
        return nil;
    }

    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    for (NSString* filename in filenames) {
        NSString* path = [dir stringByAppendingPathComponent: filename];
        NSString* key = block(path, filename);
        if (key)
            result[key] = path;
    }
    return result;
}


static NSDictionary* findIOSSimulatorDirs(NSError** error) {
    NSString* dir = [NSHomeDirectory() stringByAppendingPathComponent: kSimulatorPath];
    return iterateDir(dir, error, ^NSString *(NSString* path, NSString *dirname) {
        NSString* infoPath = [path stringByAppendingPathComponent: @"device.plist"];
        NSDictionary* info = [NSDictionary dictionaryWithContentsOfFile: infoPath];
        return info[@"name"];
    });
}


static NSString* getAppBundleName(NSString* appHomeDir) {
    NSString* infoPath = [appHomeDir stringByAppendingPathComponent: @".com.apple.mobile_container_manager.metadata.plist"];
    NSDictionary* info = [NSDictionary dictionaryWithContentsOfFile: infoPath];
    NSString* appBundleID = info[@"MCMMetadataIdentifier"];
    return appBundleID;
#if 0
    NSArray* appBundles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: appHomeDir
                                                                              error: NULL];
    appBundles = [appBundles pathsMatchingExtensions: @[@"app"]];
    return appBundles.count > 0 ? appBundles[0] : nil;
#endif
}


static NSDictionary* findAppDirs(NSString* osDir, NSError** error) {
    NSString* appsDir = [osDir stringByAppendingPathComponent: @"data/Containers/Data/Application"];
    return iterateDir(appsDir, error, ^NSString *(NSString* appHomeDir, NSString *dirName) {
        NSString* cblPath = [appHomeDir stringByAppendingPathComponent: kIOSDbDirPath];
        if (![[NSFileManager defaultManager] fileExistsAtPath: cblPath])
            return nil;
        return getAppBundleName(appHomeDir);
    });
}


static NSDictionary* findAppDatabases(NSString* appHomeDir, NSError** error) {
    NSString* cblPath = [appHomeDir stringByAppendingPathComponent: kIOSDbDirPath];
    return iterateDir(cblPath, error, ^NSString *(NSString* path, NSString *filename) {
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
    NSMutableDictionary* dirs = iterateDir(dirName, error, ^NSString *(NSString* appDirPath, NSString *appDirName) {
        NSString* cblPath = [appDirPath stringByAppendingPathComponent: kDbDirName];
        BOOL isDir;
        if (![[NSFileManager defaultManager] fileExistsAtPath: cblPath isDirectory: &isDir]
                || !isDir)
            return nil;
        return [[appDirName componentsSeparatedByString: @"."] lastObject];
    });

#if 1
    // Now look for sandboxed apps:
    dirName = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];
    dirName = [dirName stringByAppendingPathComponent: @"Containers"];

    NSArray* filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: dirName
                                                                             error: NULL];
    for (NSString* appDirName in filenames) {
        NSString* appDirPath = [[[dirName stringByAppendingPathComponent: appDirName]
                                    stringByAppendingPathComponent: @"Data/Library/Application Support"]
                                    stringByAppendingPathComponent: appDirName];
        NSString* cblPath = [appDirPath stringByAppendingPathComponent: kDbDirName];
        BOOL isDir;
        if ([[NSFileManager defaultManager] fileExistsAtPath: cblPath isDirectory: &isDir]
                && isDir) {
            NSString* displayName = [[appDirName componentsSeparatedByString: @"."] lastObject];
            dirs[displayName] = appDirPath;
        }
    }
#endif

    return dirs;
}


static NSDictionary* findMacAppDatabases(NSString* appSupportDir, NSError** error) {
    NSString* cblPath = [appSupportDir stringByAppendingPathComponent: kDbDirName];
    return iterateDir(cblPath, error, ^NSString *(NSString* path, NSString *filename) {
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
            appNode.bundleID = app;

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
            [root.children insertObject: versNode atIndex: 0];  // reverse order (newest OS first)
    }

    // Now find Mac apps:
    AppListNode* versNode = [[AppListNode alloc] initWithType: kOSNode path: @"" displayName: @"Mac OS"];
    versNode.isMacOS = YES;
    NSDictionary* apps = findMacAppDirs(outError);
    if (!apps)
        return nil;
    for (NSString* app in sortedKeys(apps)) {
        AppListNode* appNode = [[AppListNode alloc] initWithType: kAppNode path: apps[app] displayName: app];
        appNode.isMacOS = YES;
        appNode.bundleID = [apps[app] lastPathComponent];

        NSDictionary* dbs = findMacAppDatabases(apps[app],  outError);
        if (dbs) {
            for (NSString* db in sortedKeys(dbs)) {
                AppListNode* dbNode = [[AppListNode alloc] initWithType: kDbNode path: dbs[db] displayName: db];
                [appNode.children addObject: dbNode];
            }
            if (appNode.children.count > 0)
                [versNode.children addObject: appNode];
        }
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
