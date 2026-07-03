//
//  DTPlaylistWindowController.m
//  DeToca — fio 9, rebuilt fio 10
//

#import "DTPlaylistWindowController.h"
#import "DTSpotAPI.h"
#import "DTCoverCache.h"
#import "DTTrackItem.h"
#import "DTPlaylistItem.h"
#import "DTTrackCell.h"
#import "GopherTableView.h"
#import "DTPlayerWindowController.h"   // DTPlayerNowChangedNotification
#import "DTTheme.h"

#define DT_PL_W 340.0
#define DT_PL_H 400.0
#define DT_ROW_H 72.0        // track rows (thumbnail)
#define DT_PL_ROW_H 22.0     // playlist rows (text only)

enum {
    DTPlaylistModeSearch    = 0,
    DTPlaylistModeQueue     = 1,
    DTPlaylistModePlaylists = 2
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
- (void)loadAllPlaylists;
- (void)loadPlaylistsPageAt:(NSInteger)offset;
- (void)configureColumnForMode;
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
        _playlistRows = [[NSMutableArray alloc] init];
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
    [_playlistRows release];
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

    // --- Mode control (Busca | Fila | Playlists) ---
    _modeControl = [[[NSSegmentedControl alloc]
        initWithFrame:NSMakeRect(12, DT_PL_H - 36, DT_PL_W - 24, 22)] autorelease];
    [_modeControl setSegmentCount:3];
    [_modeControl setLabel:@"Busca" forSegment:0];
    [_modeControl setLabel:@"Fila" forSegment:1];
    [_modeControl setLabel:@"Playlists" forSegment:2];
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
    [self configureColumnForMode];
    [_table reloadData];
    if (_mode == DTPlaylistModeQueue) {
        [self fetchQueue];
    } else if (_mode == DTPlaylistModePlaylists) {
        [self loadAllPlaylists];
    } else {
        [_panel makeFirstResponder:_searchField];
    }
    [self updateEmptyState];
}

// The list shows two very different row shapes: tall track rows with a 64px
// thumbnail (Busca / Fila) vs. short text rows for playlists (no cover — Spotify
// exposes no playlist image, and track drill-down is 403 in dev-mode).
- (void)configureColumnForMode
{
    NSTableColumn *col = [[_table tableColumns] objectAtIndex:0];
    if (_mode == DTPlaylistModePlaylists) {
        [_table setRowHeight:DT_PL_ROW_H];
        NSTextFieldCell *tc = [[[NSTextFieldCell alloc] init] autorelease];
        [tc setFont:[DTTheme uiFontOfSize:12.0]];
        [tc setTextColor:[DTTheme textPrimary]];
        [tc setDrawsBackground:NO];
        [tc setBordered:NO];
        [tc setLineBreakMode:NSLineBreakByTruncatingTail];
        [col setDataCell:tc];
    } else {
        [_table setRowHeight:DT_ROW_H];
        [col setDataCell:[[[DTTrackCell alloc] init] autorelease]];
    }
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
    NSInteger row = [self actionRow];
    if (row < 0) {
        return;
    }
    if (_mode == DTPlaylistModeSearch) {
        if (row >= (NSInteger)[_searchRows count]) {
            return;
        }
        NSString *uri = [[_searchRows objectAtIndex:row] objectForKey:@"uri"];
        if ([uri length] == 0) {
            return;
        }
        [_api playTrackURI:uri handler:nil];   // player reflects it on its next poll
        [_statusLabel setStringValue:@"tocando…"];
    } else if (_mode == DTPlaylistModePlaylists) {
        if (row >= (NSInteger)[_playlistRows count]) {
            return;
        }
        // Play the playlist as a CONTEXT (offset 0) — next/prev then follow the
        // playlist order. No track drill-down (Spotify 403s playlist reads); this
        // path resolves server-side and needs no track-read access.
        DTPlaylistItem *pl = [_playlistRows objectAtIndex:row];
        NSString *ctx = [pl contextURI];
        if ([ctx length] == 0) {
            return;
        }
        [_api playContextURI:ctx offset:0 handler:nil];
    }
    // Queue mode is display-only.
}

#pragma mark - Playlists (list + play-by-context)

- (void)loadAllPlaylists
{
    if (_playlistsLoaded) {
        [self updateEmptyState];
        return;   // cached for the session
    }
    if (_playlistsLoading) {
        return;
    }
    _playlistsLoading = YES;
    [_playlistRows removeAllObjects];
    [self updateEmptyState];
    [self loadPlaylistsPageAt:0];
}

- (void)loadPlaylistsPageAt:(NSInteger)offset
{
    [_api playlistsAtOffset:offset handler:^(NSArray *items, NSInteger total,
                                             NSInteger off, DTSpotAPIError *error) {
        if (error != nil) {
            _playlistsLoading = NO;
            if (_mode == DTPlaylistModePlaylists) {
                [_emptyLabel setStringValue:@"erro ao carregar playlists"];
                [_emptyLabel setHidden:NO];
            }
            return;
        }
        [_playlistRows addObjectsFromArray:items];
        _playlistsTotal = total;
        NSInteger loaded = (NSInteger)[_playlistRows count];
        if (_mode == DTPlaylistModePlaylists) {
            [_table reloadData];
        }
        // Page through the whole list (20/page) once, then cache it.
        if (loaded < total && [items count] > 0) {
            [self loadPlaylistsPageAt:loaded];
        } else {
            _playlistsLoading = NO;
            _playlistsLoaded = YES;
        }
        [self updateEmptyState];
    }];
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
    NSString *msg = nil;
    if (_mode == DTPlaylistModeQueue) {
        if (_queueLoaded && [_queueRows count] == 0) {
            msg = @"rádio automático — a fila está vazia";
        }
    } else if (_mode == DTPlaylistModePlaylists) {
        if ([_playlistRows count] == 0) {
            msg = _playlistsLoading ? @"carregando playlists…"
                : (_playlistsLoaded ? @"nenhuma playlist" : nil);
        }
    }
    if (msg != nil) {
        [_emptyLabel setStringValue:msg];
        [_emptyLabel setHidden:NO];
    } else {
        [_emptyLabel setHidden:YES];
    }
}

#pragma mark - Rows + thumbnails

- (NSArray *)rowsForCurrentMode
{
    if (_mode == DTPlaylistModeQueue) {
        return _queueRows;
    }
    if (_mode == DTPlaylistModePlaylists) {
        return _playlistRows;
    }
    return _searchRows;
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
    if (_mode == DTPlaylistModePlaylists) {
        DTPlaylistItem *pl = [rows objectAtIndex:row];
        NSString *name = ([pl.name length] > 0) ? pl.name : @"(sem nome)";
        // tracks_len is 0 for ~all playlists under Spotify's dev-mode block, so
        // show the count only when it's meaningfully present.
        if (pl.tracksLen > 0) {
            return [NSString stringWithFormat:@"%@   ·   %ld faixas", name, (long)pl.tracksLen];
        }
        return name;
    }
    return [rows objectAtIndex:row];   // the { track, artist, image } dict
}

- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)column
              row:(NSInteger)row
{
    // Keep playlist text legible on the dark list (the text cell would otherwise
    // draw near-black); DTTrackCell ignores this and draws its own colors.
    if (_mode == DTPlaylistModePlaylists && [cell respondsToSelector:@selector(setTextColor:)]) {
        [cell setTextColor:[DTTheme textPrimary]];
    }
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)note
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

@end
