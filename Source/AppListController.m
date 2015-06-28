//
//  AppListController.m
//  Couchbase Lite Viewer
//
//  Created by Jens Alfke on 9/25/13.
//  Copyright (c) 2013 Couchbase, Inc. All rights reserved.
//

#import "AppListController.h"
#import "AppList.h"


@interface AppListBrowserCell : NSBrowserCell
@end

@implementation AppListBrowserCell
- (void) setObjectValue: (id)value {
    if ([value isKindOfClass:[NSArray class]]) {
        [self setStringValue: value[0]];
        [self setImage: value[1]];
        self.leaf = YES; // cell draws incorrectly (double triangle) unless I set this (why?!)
    } else {
        [super setObjectValue:value];
    }
}

@end




@interface AppListController () <NSBrowserDelegate>
{
    IBOutlet NSBrowser* _browser;

    AppListNode* _root;
}
@end

@implementation AppListController


static AppListController* sInstance;


+ (void) _show {
    if (!sInstance)
        sInstance = [[self alloc] initWithWindowNibName: @"AppListController"];
    [sInstance showWindow: self];
}

+ (void) show {
    [self _show];
    [[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"AppListShowing"];
}


+ (void) restore {
    if ([[NSUserDefaults standardUserDefaults] boolForKey: @"AppListShowing"])
        [self _show];
}


- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        NSError* error;
        _root = BuildAppList(&error);
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    _browser.delegate = self;
    _browser.cellClass = [AppListBrowserCell class];
    _browser.rowHeight = 24.0;
    _browser.titled = YES;
    _browser.takesTitleFromPreviousColumn = NO;

    _browser.target = self;
    _browser.doubleAction = @selector(openItem:);
}


- (BOOL) windowShouldClose: (id)sender {
    [[NSUserDefaults standardUserDefaults] setBool: NO forKey: @"AppListShowing"];
    return YES;
}

- (void) windowWillClose: (NSNotification*)n {
    if (self == sInstance) {
        sInstance = nil;
    }
}


- (IBAction) openItem: (id)sender {
    NSIndexPath* path = [_browser selectionIndexPath];
    if (!path)
        return;
    AppListNode* item = [_browser itemAtIndexPath: path];
    NSURL* url = [NSURL fileURLWithPath: item.path];
    if (item.type == kDbNode) {
        [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL: url
                                                                               display: YES
                                                                     completionHandler:
         ^(NSDocument * document, BOOL documentWasAlreadyOpen, NSError *error) {
             if (error)
                 [self presentError: error];
         }];
    }
}


- (id)rootItemForBrowser:(NSBrowser *)browser{
    return _root;
}

- (NSInteger)browser:(NSBrowser *)browser numberOfChildrenOfItem:(AppListNode*)item {
    return item.children.count;
}


- (id)browser:(NSBrowser *)browser child:(NSInteger)index ofItem:(AppListNode*)item {
    return item.children[index];
}


- (BOOL)browser:(NSBrowser *)browser isLeafItem:(AppListNode*)item {
    return item.type == kDbNode;
}


- (id)browser:(NSBrowser *)browser objectValueForItem:(AppListNode*)item{
    return item.nameAndIcon;
}

- (NSString*) browser:(NSBrowser *)sender titleOfColumn:(NSInteger)column {
    return @[@"Platforms", @"Apps", @"Databases"][column];
}


@end
