//
//  BookmarkStore.h
//  DeToca
//
//  Bookmarks are just a hand-editable gophermap at
//  ~/Library/Application Support/DeToca/bookmarks.gophermap. The Bookmarks
//  window renders it through the ordinary menu path; adding a bookmark appends
//  a gophermap line.
//

#import <Foundation/Foundation.h>

@class GopherResource;

@interface BookmarkStore : NSObject

// Full path to the bookmarks gophermap (does not guarantee existence).
+ (NSString *)bookmarksPath;

// Create the support directory and a seeded bookmarks file if missing.
+ (void)ensureExists;

// The bookmarks gophermap text (creating the seed file if needed).
+ (NSString *)bookmarksText;

// Append a bookmark line built from a resource. Returns NO on write failure.
+ (BOOL)addBookmarkForResource:(GopherResource *)resource;

@end
