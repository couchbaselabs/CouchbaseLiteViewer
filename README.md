This is a fairly simple Mac editor for [TouchDB](https://github.com/couchbaselabs/TouchDB-iOS) databases.

## Features

1. Open any TouchDB database file on a reachable filesystem
2. View all documents including revision IDs and sequence numbers
3. View and modify JSON properties of any document
4. Add and remove documents

## Requirements

* Mac OS X 10.7+.
* Xcode 4.3+ to build it.

## Building It

* Get [Syncpoint](https://github.com/couchbaselabs/Syncpoint-iOS)
* Copy or symlink Syncpoint.framework into the `Frameworks/` subdirectory.
* Open `TouchDB Viewer.xcodeproj`.
* Product > Build
