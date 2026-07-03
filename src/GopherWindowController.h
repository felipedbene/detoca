//
//  GopherWindowController.h
//  DeToca
//
//  One window = one Gopher resource. Menus (type 1/7) render in a table; text
//  (type 0) renders in a non-wrapping text view with ANSI styling. Activating a
//  menu row asks the AppDelegate to open a new (cascaded) window — the window
//  trail is the history (no back/forward). Also renders local gophermap text
//  for the Bookmarks window.
//

#import <Cocoa/Cocoa.h>
#import "GopherRequest.h"
#import "GopherMenuView.h"

@class GopherResource;

@interface GopherWindowController : NSWindowController
    <GopherRequestDelegate, NSWindowDelegate, GopherMenuViewDelegate> {
    GopherResource      *_resource;
    GopherRequest       *_request;
    NSArray             *_items;         // GopherItem list (menu mode)
    NSString            *_localText;     // supplied text (Bookmarks); no fetch

    NSProgressIndicator *_spinner;       // not retained (owned by view tree)
    NSTextField         *_statusLabel;   // not retained
    GopherMenuView      *_menuView;      // not retained (owned by view tree)
    NSTextView          *_textView;      // not retained
    NSView              *_bodyArea;      // not retained

    BOOL                 _menuMode;
}

@property (nonatomic, retain, readonly) GopherResource *resource;

- (id)initWithResource:(GopherResource *)resource parentWindow:(NSWindow *)parent;

// Begin fetching (called automatically after the window appears).
- (void)startFetch;

// Render supplied gophermap text as a menu with no network fetch.
- (void)loadLocalMenuText:(NSString *)text;

// The menu's playable audio-stream items (h/URL: rows whose URL is an MP3
// stream), in menu order. Used to build the player queue and to export M3U.
- (NSArray *)playableStreamItems;

@end
