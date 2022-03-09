⚠️ This repo is obsolete and the new preferred method for viewing databases is the [Visual Studio Code Plugin](https://github.com/couchbaselabs/vscode-cblite).

This is a fairly simple Mac editor for [Couchbase Lite](https://github.com/couchbase/CouchbaseLite-iOS) databases.

## Features

0. Browse the databases of all iOS apps in the Simulator, and all Mac apps.
1. Open any Couchbase Lite database file on a reachable filesystem
2. View all documents including revision IDs and sequence numbers
3. View and modify JSON properties of any document
4. View document history as a full revision tree (by double-clicking a document row)
5. Add and remove documents

## Requirements

* Mac OS X 10.7+.
* Xcode 6+ to build it.

## Building It

* Get [Couchbase Lite](http://www.couchbase.com/nosql-databases/downloads)
* Copy or symlink Couchbase Lite.framework into the `Frameworks/` subdirectory.
* Open `Couchbase Lite Viewer.xcodeproj`.
* Product > Build

## Using It

Use the browser window to find your app. Mac apps are in one group, iOS apps are grouped by simulator type.

Once you select your app you'll see its databases; double-click one to open it.

The database viewer window lists all the documents in the left pane, and shows the properties of the selected document in the right pane. (You can add any property you want as a column in the left pane by right-clicking it in the right pane and selecting "Add Column".)

Should you want to view the revision history of a document, double-click it in the left pane. Click the navigation control at the top to return to the document list.
