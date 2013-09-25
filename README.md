This is a fairly simple Mac editor for [Couchbase Lite](https://github.com/couchbase/CouchbaseLite-iOS) databases.

## Features

1. Open any Couchbase Lite database file on a reachable filesystem
2. View all documents including revision IDs and sequence numbers
3. View and modify JSON properties of any document
4. View document history as a full revision tree (by double-clicking a document row)
5. Add and remove documents

## Requirements

* Mac OS X 10.7+.
* Xcode 4.6+ to build it.

## Building It

* Get [Couchbase Lite](https://github.com/couchbase/CouchbaseLite-iOS)
* Copy or symlink Couchbase Lite.framework into the `Frameworks/` subdirectory.
* Open `Couchbase Lite Viewer.xcodeproj`.
* Product > Build

## Using It

You'll need to locate the database's `.cblite` file:

A Mac OS application's databases are by default in ~/Library/Application Support/_bundleID_/CouchbaseLite/ , unless you used a custom path for your CBLManager.

LiteServ's databases are as above, where the _bundleID_ is `com.couchbase.LiteServ`.

The files of an iOS app running in the simulator can be hard to find. The path to the app tends to look like ~/Library/Application Support/iPhone Simulator/_version_/Applications/_uuid_. Within that, the databases will be in the subdirectory Library/Application Support/CouchbaseLite. If you're having trouble finding the app directory, try logging `[[NSBundle mainBundle] bundlePath]` at launch time.
