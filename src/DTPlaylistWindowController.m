//
//  DTPlaylistWindowController.m
//  DeToca — fio 9, rebuilt fio 10
//

#import "DTPlaylistWindowController.h"
#import "DTSpotAPI.h"
#import "DTCoverCache.h"
#import "DTTrackItem.h"
#import "DTTrackCell.h"
#import "GopherTableView.h"
#import "DTPlayerWindowController.h"   // DTPlayerNowChangedNotification
#import "DTTheme.h"

#define DT_PL_W 340.0
#define DT_PL_H 400.0
#define DT_ROW_H 72.0

enum {
    DTPlaylistModeSearch = 0,
    DTPlaylistModeQueue  = 1
};

@interface DTPlaylistWindowController ()
- (void)buildPanel;
- (void)layoutForMode;
- (void)onMode:(id)sender;
- (void)search:(id)sender;
- (void)onPlay:(id)sender;
- (void)onEnqueue:(id)sender;
- (void)fetchQueue;
- (void)refetchQueue;
- (void)clearStatus;
- (void)updateEmptyState;
- (void)playerNowChanged:(NSNotification *)note;
- (NSArray *)rowsForCurrentMode;
- (NSMutableArray *)rowsFromItems:(NSArray *)items;
- (void)kickThumbnailsFor:(NSMutableArray *)rows;
- (void)redrawRowForModel:(id)model;
@end

@implementation DTPlaylistWindowController

- (id)init
{
    self = [super init];
    if (self != nil) {
        _api = [[DTSpotAPI alloc] init];
        _searchRows = [[NSMutableArray alloc] init];
        _queueRows = [[NSMutableArray alloc] init];
        _mode = DTPlaylistModeSearch;

        // Own cover cache (its own memory), sharing the on-disk store with the
        // player's — a cover fetched by either window is a disk hit for the other.
        _coverCache = [[DTCoverCache alloc] init];
        DTSpotAPI *api = _api;
        [_coverCache setFetcher:^(NSString *albumId, NSInteger size, void (^done)(NSData *)) {
            [api coverForAlbum:albumId size:size handler:^(NSData *jpeg, DTSpotAPIError *err) {
                done(jpeg);
            }];
        }];

        // Refresh "up next" off the player's existing /now poll — no second timer.
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(playerNowChanged:)
                   name:DTPlayerNowChangedNotification
                 object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_api release];
    [_coverCache release];
    [_searchRows release];
    [_queueRows release];
    [_panel release];
    [super dealloc];
}

#pragma mark - Panel

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
    [_panel setBecomesKeyOnlyIfNeeded:NO];
    [_panel setMinSize:NSMakeSize(DT_PL_W, 260)];
    [_panel setDelegate:self];

    NSView *c = [_panel contentView];

    // --- Mode control (Busca | Fila; Playlists lands in fio 10/4) ---
    _modeControl = [[[NSSegmentedControl alloc]
        initWithFrame:NSMakeRect(12, DT_PL_H - 36, DT_PL_W - 24, 22)] autorelease];
    [_modeControl setSegmentCount:2];
    [_modeControl setLabel:@"Busca" forSegment:0];
    [_modeControl setLabel:@"Fila" forSegment:1];
    [[_modeControl cell] setTrackingMode:NSSegmentSwitchTrackingSelectOne];
    [_modeControl setSelectedSegment:DTPlaylistModeSearch];
    [_modeControl setTarget:self];
    [_modeControl setAction:@selector(onMode:)];
    [_modeControl setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [c addSubview:_modeControl];

    // --- Search field (Busca) ---
    _searchField = [DTTheme darkFieldWithFrame:
        NSMakeRect(12, DT_PL_H - 66, DT_PL_W - 24, 22)];
    [[_searchField cell] setPlaceholderString:@"buscar músicas…"];
    [_searchField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [_searchField setTarget:self];
    [_searchField setAction:@selector(search:)];
    [c addSubview:_searchField];

    // --- List (results / queue) ---
    _scroll = [[[NSScrollView alloc]
        initWithFrame:NSMakeRect(12, 48, DT_PL_W - 24, DT_PL_H - 122)] autorelease];
    [_scroll setHasVerticalScroller:YES];
    [_scroll setAutohidesScrollers:YES];
    [_scroll setBorderType:NSBezelBorder];
    [_scroll setDrawsBackground:YES];
    [_scroll setBackgroundColor:[DTTheme background]];
    [_scroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

    _table = [[[GopherTableView alloc] initWithFrame:[[_scroll contentView] bounds]] autorelease];
    [_table setBackgroundColor:[DTTheme background]];
    [_table setHeaderView:nil];
    [_table setUsesAlternatingRowBackgroundColors:NO];
    [_table setGridStyleMask:NSTableViewGridNone];
    [_table setRowHeight:DT_ROW_H];
    [_table setDataSource:self];
    [_table setDelegate:self];
    [_table setTarget:self];
    [_table setDoubleAction:@selector(onPlay:)];

    NSTableColumn *col = [[[NSTableColumn alloc] initWithIdentifier:@"track"] autorelease];
    [col setWidth:DT_PL_W - 44];
    [col setEditable:NO];
    [col setDataCell:[[[DTTrackCell alloc] init] autorelease]];
    [_table addTableColumn:col];

    [_scroll setDocumentView:_table];
    [c addSubview:_scroll];

    // --- Centered empty-state (Fila with no queue) ---
    _emptyLabel = [DTTheme labelWithFrame:NSMakeRect(24, DT_PL_H / 2.0 - 10, DT_PL_W - 48, 20)
                                     size:12.0 color:[DTTheme textDim]];
    [_emptyLabel setAlignment:NSCenterTextAlignment];
    [_emptyLabel setStringValue:@"rádio automático — a fila está vazia"];
    [_emptyLabel setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin)];
    [_emptyLabel setHidden:YES];
    [c addSubview:_emptyLabel];

    // --- Action row (Busca): Tocar / Enfileirar + transient status ---
    _playButton = [DTTheme buttonWithFrame:NSMakeRect(12, 12, 96, 28)
                                     title:@"▶ Tocar" target:self action:@selector(onPlay:)];
    [_playButton setAutoresizingMask:NSViewMaxYMargin];
    [c addSubview:_playButton];

    _enqueueButton = [DTTheme buttonWithFrame:NSMakeRect(112, 12, 108, 28)
                                        title:@"＋ Fila" target:self action:@selector(onEnqueue:)];
    [_enqueueButton setAutoresizingMask:NSViewMaxYMargin];
    [c addSubview:_enqueueButton];

    _statusLabel = [DTTheme labelWithFrame:NSMakeRect(226, 17, DT_PL_W - 226 - 12, 18)
                                      size:11.0 color:[DTTheme textMuted]];
    [_statusLabel setAlignment:NSRightTextAlignment];
    [_statusLabel setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [c addSubview:_statusLabel];

    [_panel center];
    [self layoutForMode];
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
    if (_mode == DTPlaylistModeSearch) {
        [_panel makeFirstResponder:_searchField];
    } else {
        [self fetchQueue];
    }
}

#pragma mark - Modes

- (void)layoutForMode
{
    BOOL search = (_mode == DTPlaylistModeSearch);
    [_searchField setHidden:!search];
    [_playButton setHidden:!search];
    [_enqueueButton setHidden:!search];
    [_statusLabel setHidden:!search];

    NSRect f = search
        ? NSMakeRect(12, 48, DT_PL_W - 24, DT_PL_H - 122)   // below the search field
        : NSMakeRect(12, 12, DT_PL_W - 24, DT_PL_H - 86);   // below the segment
    [_scroll setFrame:f];
}

- (void)onMode:(id)sender
{
    _mode = [_modeControl selectedSegment];
    [self layoutForMode];
    [_table reloadData];
    if (_mode == DTPlaylistModeQueue) {
        [self fetchQueue];
    } else {
        [_panel makeFirstResponder:_searchField];
    }
    [self updateEmptyState];
}

#pragma mark - Search + actions

- (void)search:(id)sender
{
    NSString *query = [[_searchField stringValue]
                       stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([query length] == 0) {
        return;
    }
    _searchGen++;
    NSUInteger gen = _searchGen;
    [_statusLabel setStringValue:@"buscando…"];
    [_api search:query handler:^(NSArray *items, DTSpotAPIError *error) {
        if (gen != _searchGen) {
            return;   // a newer search superseded this response
        }
        [_searchRows release];
        _searchRows = [[self rowsFromItems:items] retain];
        if (_mode == DTPlaylistModeSearch) {
            [_table reloadData];
        }
        [self kickThumbnailsFor:_searchRows];
        if (error != nil) {
            [_statusLabel setStringValue:@"erro na busca"];
        } else {
            [_statusLabel setStringValue:([_searchRows count] == 0 ? @"nada encontrado" : @"")];
        }
    }];
}

- (NSInteger)actionRow
{
    NSInteger row = [_table clickedRow];
    if (row < 0) {
        row = [_table selectedRow];
    }
    return row;
}

- (void)onPlay:(id)sender
{
    if (_mode != DTPlaylistModeSearch) {
        return;
    }
    NSInteger row = [self actionRow];
    if (row < 0 || row >= (NSInteger)[_searchRows count]) {
        return;
    }
    NSString *uri = [[_searchRows objectAtIndex:row] objectForKey:@"uri"];
    if ([uri length] == 0) {
        return;
    }
    [_api playTrackURI:uri handler:nil];   // player reflects it on its next poll
    [_statusLabel setStringValue:@"tocando…"];
}

- (void)onEnqueue:(id)sender
{
    if (_mode != DTPlaylistModeSearch) {
        return;
    }
    NSInteger row = [self actionRow];
    if (row < 0 || row >= (NSInteger)[_searchRows count]) {
        return;
    }
    NSString *uri = [[_searchRows objectAtIndex:row] objectForKey:@"uri"];
    if ([uri length] == 0) {
        return;
    }
    [_statusLabel setStringValue:@"enfileirando…"];
    [_api queueAddURI:uri handler:^(NSArray *items, DTSpotAPIError *error) {
        if (error != nil) {
            [_statusLabel setStringValue:@"erro ao enfileirar"];
            return;
        }
        // The reply is the fresh /queue; adopt it, then re-poll once it settles
        // (Spotify is eventually consistent for ~1–2 s after an add).
        [_queueRows release];
        _queueRows = [[self rowsFromItems:items] retain];
        _queueLoaded = YES;
        [self kickThumbnailsFor:_queueRows];
        if (_mode == DTPlaylistModeQueue) {
            [_table reloadData];
            [self updateEmptyState];
        }
        [_statusLabel setStringValue:@"✓ na fila"];
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(refetchQueue) object:nil];
        [self performSelector:@selector(refetchQueue) withObject:nil afterDelay:1.6];
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(clearStatus) object:nil];
        [self performSelector:@selector(clearStatus) withObject:nil afterDelay:2.6];
    }];
}

- (void)clearStatus
{
    [_statusLabel setStringValue:@""];
}

#pragma mark - Queue

- (void)refetchQueue
{
    [self fetchQueue];
}

- (void)fetchQueue
{
    [_api fetchQueue:^(NSArray *items, DTSpotAPIError *error) {
        if (error != nil) {
            return;   // transient: keep the last known queue
        }
        [_queueRows release];
        _queueRows = [[self rowsFromItems:items] retain];
        _queueLoaded = YES;
        [self kickThumbnailsFor:_queueRows];
        if (_mode == DTPlaylistModeQueue) {
            [_table reloadData];
            [self updateEmptyState];
        }
    }];
}

- (void)playerNowChanged:(NSNotification *)note
{
    // The player's /now poll saw a track/queue change; refresh only when we're
    // actually showing the queue (otherwise onMode refetches on entry).
    if (_panel != nil && [_panel isVisible] && _mode == DTPlaylistModeQueue) {
        [self fetchQueue];
    }
}

- (void)updateEmptyState
{
    BOOL show = (_mode == DTPlaylistModeQueue) && _queueLoaded && ([_queueRows count] == 0);
    [_emptyLabel setHidden:!show];
}

#pragma mark - Rows + thumbnails

- (NSArray *)rowsForCurrentMode
{
    return (_mode == DTPlaylistModeQueue) ? _queueRows : _searchRows;
}

- (NSMutableArray *)rowsFromItems:(NSArray *)items
{
    NSMutableArray *rows = [NSMutableArray array];
    NSUInteger i, n = [items count];
    for (i = 0; i < n; i++) {
        DTTrackItem *it = [items objectAtIndex:i];
        NSMutableDictionary *r = [NSMutableDictionary dictionary];
        if ([it.track length])   { [r setObject:it.track   forKey:@"track"]; }
        if ([it.artist length])  { [r setObject:it.artist  forKey:@"artist"]; }
        if ([it.uri length])     { [r setObject:it.uri     forKey:@"uri"]; }
        if ([it.albumId length]) { [r setObject:it.albumId forKey:@"albumId"]; }
        [rows addObject:r];
    }
    return rows;
}

- (void)kickThumbnailsFor:(NSMutableArray *)rows
{
    NSUInteger i, n = [rows count];
    for (i = 0; i < n; i++) {
        NSMutableDictionary *r = [rows objectAtIndex:i];
        NSString *albumId = [r objectForKey:@"albumId"];
        if ([albumId length] == 0 || [r objectForKey:@"image"] != nil) {
            continue;
        }
        NSMutableDictionary *rowRef = r;
        [_coverCache coverForAlbum:albumId size:64 handler:^(NSData *jpeg) {
            if ([jpeg length] == 0) {
                return;
            }
            NSImage *img = [[[NSImage alloc] initWithData:jpeg] autorelease];
            if (img == nil) {
                return;
            }
            [rowRef setObject:img forKey:@"image"];
            [self redrawRowForModel:rowRef];
        }];
    }
}

- (void)redrawRowForModel:(id)model
{
    NSArray *rows = [self rowsForCurrentMode];
    NSUInteger idx = [rows indexOfObjectIdenticalTo:model];
    if (idx != NSNotFound) {
        [_table setNeedsDisplayInRect:[_table frameOfCellAtColumn:0 row:(NSInteger)idx]];
    }
}

#pragma mark - NSTableView data source / delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return (NSInteger)[[self rowsForCurrentMode] count];
}

- (id)tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)column
                          row:(NSInteger)row
{
    NSArray *rows = [self rowsForCurrentMode];
    if (row < 0 || row >= (NSInteger)[rows count]) {
        return nil;
    }
    return [rows objectAtIndex:row];   // the { track, artist, image } dict
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)note
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

@end
