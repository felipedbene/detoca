//
//  GopherMenuView.h
//  DeToca — fio 6
//
//  A reusable Gopher menu list: an NSScrollView + GopherTableView rendering a
//  GopherItem array with the dark terminal theme (monospace document font,
//  bracketed type tags, per-kind colors, tight rows for ASCII-art info lines).
//  Activation (double-click / Return on a clickable row) is reported to a
//  delegate. Used by GopherWindowController (menu windows) and by the radinho's
//  embedded gopher-spot browser.
//

#import <Cocoa/Cocoa.h>

@class GopherMenuView;
@class GopherItem;
@class GopherTableView;

@protocol GopherMenuViewDelegate <NSObject>
- (void)gopherMenuView:(GopherMenuView *)view didActivateItem:(GopherItem *)item;
@end

@interface GopherMenuView : NSView <NSTableViewDataSource, NSTableViewDelegate> {
    NSScrollView    *_scrollView;
    GopherTableView *_tableView;
    NSArray         *_items;
    id <GopherMenuViewDelegate> _menuDelegate;   // not retained
}

@property (nonatomic, assign) id <GopherMenuViewDelegate> menuDelegate;

- (void)setItems:(NSArray *)items;
- (NSArray *)items;

// The underlying table, e.g. so a host can make it first responder.
- (GopherTableView *)tableView;

@end
