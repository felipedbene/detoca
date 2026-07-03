//
//  AppDelegate.h
//  DeToca
//
//  Application delegate: owns the set of open windows, builds the menu bar in
//  code (no NIB), and is the single navigation hub. Opening a menu item routes
//  through here so the h/URL: external-handoff has one dispatch point (the
//  fio-2 QTKit swap site).
//

#import <Cocoa/Cocoa.h>

@class GopherResource;
@class GopherItem;
@class GopherWindowController;
@class PreferencesController;

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    NSMutableArray        *_controllers;   // open GopherWindowControllers
    PreferencesController *_prefs;
    NSString              *_initialURLString;  // optional launch location
}

// If set before launch finishes, this location opens instead of Home. Set from
// a "gopher://…" command-line argument (see main.m).
@property (nonatomic, copy) NSString *initialURLString;

// Navigation.
- (GopherWindowController *)openResource:(GopherResource *)resource
                              fromWindow:(NSWindow *)parent;
- (void)openItem:(GopherItem *)item fromWindow:(NSWindow *)parent;

// Single dispatch point for h/URL: links. fio 2 replaces this body with an
// in-app QTKit player for gopher-spot streams.
- (void)openExternalURLString:(NSString *)urlString;

// Called by a window controller as its window closes.
- (void)gopherWindowWillClose:(GopherWindowController *)controller;

// Menu actions.
- (void)openHome:(id)sender;          // Cmd-Shift-H
- (void)openLocation:(id)sender;      // Cmd-L
- (void)showBookmarks:(id)sender;
- (void)addBookmark:(id)sender;       // Cmd-D
- (void)showPreferences:(id)sender;   // Cmd-,

@end
