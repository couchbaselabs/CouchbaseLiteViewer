This is a fairly simple Mac editor for [TouchDB](https://github.com/couchbaselabs/TouchDB-iOS) databases.

## Features

1. Open any TouchDB database file on a reachable filesystem
2. View all documents including revision IDs and sequence numbers
3. View and modify JSON properties of any document
4. View document history as a full revision tree
5. Add and remove documents

## Requirements

* Mac OS X 10.7+.
* Xcode 4.4+ to build it.

## Building It

* Get [TouchDB](https://github.com/couchbaselabs/TouchDB-iOS)
* Copy or symlink TouchDB.framework into the `Frameworks/` subdirectory.
* Get [CouchCocoa](https://github.com/couchbaselabs/CouchCocoa)
* Copy or symlink CouchCocoa.framework into the `Frameworks/` subdirectory.
* Open `TouchDB Viewer.xcodeproj`.
* Product > Build
