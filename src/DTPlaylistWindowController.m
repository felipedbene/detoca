//
//  DTPlaylistWindowController.m
//  DeToca — fio 9
//

#import "DTPlaylistWindowController.h"
#import "DTServerPrefs.h"
#import "GopherMenuParser.h"
#import "GopherItem.h"
#import "GopherTableView.h"

#define DT_PL_W 300.0
#define DT_PL_H 360.0
#define DT_SEARCH_SELECTOR @"/spot/search"
#define DT_TRACK_PREFIX @"/spot/track/"

@interface DTPlaylistWindowController ()
- (void)buildPanel;
- (void)search:(id)sender;
- (void)playRow:(id)sender;
@end

@implementation DTPlaylistWindowController

- (id)init
{
    self = [super init];
    if (self != nil) {
        _tracks = [[NSMutableArray alloc] init];
        _playingRow = -1;
    }
    return self;
}

- (void)dealloc
{
    [_searchReq cancel];
    [_searchReq release];
    [_tracks release];
    [_panel release];
    [super dealloc];
}

- (void)buildPanel
{
    NSRect rect = NSMakeRect(0, 0, DT_PL_W, DT_PL_H);
    NSUInteger style = (NSTitledWindowMask | NSClosableWindowMask |
                        NSResizableWindowMask | NSUtilityWindowMask | NSHUDWindowMask);
    _panel = [[NSPanel alloc] initWithContentRect:rect
                                        styleMask:style
                                          backing:NSBackingStoreBuffered
                                            defer:YES];
    [_panel setTitle:@"Playlist"];
    [_panel setFloatingPanel:YES];
    [_panel setLevel:NSFloatingWindowLevel];
    [_panel setHidesOnDeactivate:NO];
    [_panel setReleasedWhenClosed:NO];
    // The playlist is keyboard-driven (type to search, ↑/↓ + Return to play), so
    // it must be able to become key — unlike the float-only player transport.
    [_panel setBecomesKeyOnlyIfNeeded:NO];
    [_panel setDelegate:self];

    NSView *c = [_panel contentView];

    _searchField = [[[NSTextField alloc]
        initWithFrame:NSMakeRect(12, DT_PL_H - 34, DT_PL_W - 24, 22)] autorelease];
    [[_searchField cell] setPlaceholderString:@"buscar músicas…"];
    [_searchField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [_searchField setTarget:self];
    [_searchField setAction:@selector(search:)];
    [c addSubview:_searchField];

    NSScrollView *scroll = [[[NSScrollView alloc]
        initWithFrame:NSMakeRect(12, 12, DT_PL_W - 24, DT_PL_H - 54)] autorelease];
    [scroll setHasVerticalScroller:YES];
    [scroll setAutohidesScrollers:YES];
    [scroll setBorderType:NSBezelBorder];
    [scroll setDrawsBackground:YES];
    [scroll setBackgroundColor:[NSColor blackColor]];
    [scroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

    // GopherTableView adds Return-to-activate (fires the double-action).
    _table = [[[GopherTableView alloc] initWithFrame:[[scroll contentView] bounds]] autorelease];
    [_table setBackgroundColor:[NSColor blackColor]];
    [_table setHeaderView:nil];
    [_table setUsesAlternatingRowBackgroundColors:NO];
    [_table setGridStyleMask:NSTableViewGridNone];
    [_table setRowHeight:18.0];
    [_table setDataSource:self];
    [_table setDelegate:self];
    [_table setTarget:self];
    [_table setDoubleAction:@selector(playRow:)];

    NSTableColumn *col = [[[NSTableColumn alloc] initWithIdentifier:@"title"] autorelease];
    [col setWidth:DT_PL_W - 44];
    [col setEditable:NO];
    [_table addTableColumn:col];

    [scroll setDocumentView:_table];
    [c addSubview:scroll];

    [_panel center];
}

- (void)ensurePanel
{
    if (_panel == nil) {
        [self buildPanel];
    }
}

- (void)show
{
    [self ensurePanel];
    [_panel orderFront:self];
    [_panel makeFirstResponder:_searchField];
}

#pragma mark - Search

- (void)search:(id)sender
{
    NSString *query = [[_searchField stringValue]
                       stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([query length] == 0) {
        return;
    }
    // Type-7 request: "<searchBase><TAB><query>".
    NSString *sel = [NSString stringWithFormat:@"%@\t%@", DT_SEARCH_SELECTOR, query];
    [_searchReq cancel];
    [_searchReq release];
    _searchReq = [[GopherRequest requestWithHost:[DTServerPrefs host]
                                            port:[DTServerPrefs port]
                                        selector:sel] retain];
    [_searchReq setDelegate:self];
    [_searchReq start];
}

- (void)gopherRequest:(GopherRequest *)request didReceiveData:(NSData *)data
{
    if (request != _searchReq) {
        return;
    }
    NSArray *items = [GopherMenuParser parseMenuData:data];

    // Flatten to just the playable tracks: /spot/track/<id> -> a direct
    // /spot/play?uri=spotify:track:<id> action, no drill-down.
    [_tracks removeAllObjects];
    _playingRow = -1;
    NSUInteger i, n = [items count];
    for (i = 0; i < n; i++) {
        GopherItem *it = [items objectAtIndex:i];
        NSString *sel = [it selector];
        if (![sel hasPrefix:DT_TRACK_PREFIX]) {
            continue;
        }
        NSString *tid = [sel substringFromIndex:[DT_TRACK_PREFIX length]];
        if ([tid length] == 0) {
            continue;
        }
        NSString *play = [NSString stringWithFormat:
                          @"/spot/play?uri=spotify:track:%@", tid];
        NSString *title = [it displayString];
        [_tracks addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                            (title ? title : @""), @"title", play, @"play", nil]];
    }
    [_table reloadData];
}

- (void)gopherRequest:(GopherRequest *)request didFailWithError:(NSError *)error
{
    if (request != _searchReq) {
        return;
    }
    [_tracks removeAllObjects];
    [_table reloadData];
}

#pragma mark - Play

- (void)playRow:(id)sender
{
    NSInteger row = [_table clickedRow];
    if (row < 0) {
        row = [_table selectedRow];
    }
    if (row < 0 || row >= (NSInteger)[_tracks count]) {
        return;
    }
    NSString *play = [[_tracks objectAtIndex:row] objectForKey:@"play"];

    // Fire-and-forget the play action; the player window reflects it on its next
    // /now poll. (The response is a confirmation menu we discard.)
    GopherRequest *req = [GopherRequest requestWithHost:[DTServerPrefs host]
                                                   port:[DTServerPrefs port]
                                               selector:play];
    [req start];

    _playingRow = row;
    [_table reloadData];
}

#pragma mark - NSTableView data source / delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return (NSInteger)[_tracks count];
}

- (id)tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)column
                          row:(NSInteger)row
{
    if (row < 0 || row >= (NSInteger)[_tracks count]) {
        return @"";
    }
    return [[_tracks objectAtIndex:row] objectForKey:@"title"];
}

- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)column
              row:(NSInteger)row
{
    // Dark list; the currently-playing row glows (Phase 4 folds this into DTTheme).
    if ([cell respondsToSelector:@selector(setTextColor:)]) {
        NSColor *color = (row == _playingRow)
            ? [NSColor colorWithDeviceRed:1.0 green:0.72 blue:0.24 alpha:1.0]
            : [NSColor colorWithDeviceWhite:0.90 alpha:1.0];
        [cell setTextColor:color];
    }
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)note
{
    [_searchReq cancel];
    [_searchReq release];
    _searchReq = nil;
}

@end
