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
#import "DTMediaKeyTap.h"

@class GopherResource;
@class GopherItem;
@class GopherWindowController;
@class PreferencesController;

@interface AppDelegate : NSObject <NSApplicationDelegate, DTMediaKeyTapDelegate> {
    NSMutableArray        *_controllers;   // open GopherWindowControllers
    PreferencesController *_prefs;
    NSString              *_initialURLString;  // optional launch location
    DTMediaKeyTap         *_mediaKeys;     // global media-key capture (fio 8)
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

// Open/reveal the radinho, connecting to the current gopher-spot backend if
// needed (the Playback ▸ Open Radinho action, Cmd-R).
- (void)openRadinho:(id)sender;

// Tear down any live radinho session and reconnect to the current backend.
// Called by Preferences when the host/port changed.
- (void)reconnectRadinho;

@end
