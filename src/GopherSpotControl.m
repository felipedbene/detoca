//
//  GopherSpotControl.m
//  DeToca — fio 5
//

#import "GopherSpotControl.h"
#import "GopherItem.h"
#import "GopherMenuParser.h"
#import "PLSParser.h"
#import "SpotSelectors.h"

#define DT_NOW_POLL_INTERVAL 6.0

@interface GopherSpotControl ()
- (void)sendControl:(NSString *)command;
- (void)fireCommand:(NSString *)command;
- (void)pollNow;
- (NSString *)nowPlayingFromText:(NSString *)text;
- (void)finishResolving;
- (void)buildBrowseView;
- (void)openSelector:(NSString *)selector push:(BOOL)push;
- (void)search:(id)sender;
- (void)goBack:(id)sender;
@end

@implementation GopherSpotControl

- (id)initWithSoundItem:(GopherItem *)item player:(StreamPlayerController *)player
{
    self = [super init];
    if (self != nil) {
        _host = [[item host] copy];
        _port = [item port];
        _streamSelector = [[item selector] copy];
        _title = [[item displayString] copy];
        _player = player;   // not retained

        // Derive the control-plane selectors from the stream selector's parent
        // directory (gopher-spot convention).
        NSString *parent = [_streamSelector stringByDeletingLastPathComponent];
        if ([parent length] == 0) {
            parent = @"";
        }
        _controlBase = [[parent stringByAppendingPathComponent:@"control"] copy];
        _nowSelector = [[parent stringByAppendingPathComponent:@"now"] copy];
        _playBase    = [[parent stringByAppendingPathComponent:@"play"] copy];
        _searchBase  = [[parent stringByAppendingPathComponent:@"search"] copy];
        _rootSelector = [@"" copy];   // gopher-spot server root is the menu
        _navStack = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_host release];
    [_streamSelector release];
    [_controlBase release];
    [_nowSelector release];
    [_playBase release];
    [_searchBase release];
    [_rootSelector release];
    [_title release];
    [_streamURL release];
    [_pollRequest release];
    [_pollTimer release];
    [_browseView release];
    [_browseRequest release];
    [_navStack release];
    [_currentSelector release];
    [super dealloc];
}

- (void)begin
{
    if ([_host length] == 0 || [_streamSelector length] == 0) {
        return;
    }
    // Stay alive across the async resolve; balanced in -finishResolving.
    [self retain];
    _resolving = YES;

    GopherRequest *req = [GopherRequest requestWithHost:_host
                                                   port:_port
                                               selector:_streamSelector];
    [req setDelegate:self];
    [_pollRequest release];
    _pollRequest = [req retain];   // reuse the slot for the resolve fetch too
    [req start];
}

- (void)finishResolving
{
    if (_resolving) {
        _resolving = NO;
        [self autorelease];   // balance the -begin retain
    }
}

#pragma mark - Control commands (fire-and-forget gopher requests)

// Fire-and-forget a control selector (the confirmation menu is discarded).
- (void)sendControl:(NSString *)command
{
    if ([_controlBase length] == 0) {
        return;
    }
    NSString *sel = [_controlBase stringByAppendingPathComponent:command];
    GopherRequest *req = [GopherRequest requestWithHost:_host port:_port selector:sel];
    [req start];
}

- (void)fireCommand:(NSString *)command
{
    [self sendControl:command];
    // Refresh now-playing shortly after a transport command lands.
    [self performSelector:@selector(pollNow) withObject:nil afterDelay:0.8];
}

- (void)streamControlPlay      { [self fireCommand:@"play"]; }
- (void)streamControlPause     { [self fireCommand:@"pause"]; }
- (void)streamControlNext      { [self fireCommand:@"next"]; }
- (void)streamControlPrevious  { [self fireCommand:@"prev"]; }

- (void)streamControlWillStop
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_pollTimer invalidate];
    [_pollTimer release];
    _pollTimer = nil;
    [_pollRequest cancel];
    [_pollRequest release];
    _pollRequest = nil;
    [_browseRequest cancel];
    [_browseRequest release];
    _browseRequest = nil;
    // Remove the browser from the panel (the player collapses back to compact).
    [_player setBrowseView:nil];
    [_menuView setMenuDelegate:nil];
    _menuView = nil;
    _searchField = nil;
    [_browseView release];
    _browseView = nil;
    [_navStack removeAllObjects];
    [_currentSelector release];
    _currentSelector = nil;
}

#pragma mark - Embedded browser (fio 6)

- (void)buildBrowseView
{
    if (_browseView != nil) {
        return;
    }
    // Frame is set by -[StreamPlayerController setBrowseView:]; use a sane
    // default. Subviews autoresize within it.
    NSRect b = NSMakeRect(0, 0, 324, 320);
    _browseView = [[NSView alloc] initWithFrame:b];

    CGFloat top = b.size.height - 24.0;

    NSButton *back = [[[NSButton alloc]
        initWithFrame:NSMakeRect(0, top, 58, 22)] autorelease];
    [back setTitle:@"‹"];
    [back setBezelStyle:NSTexturedRoundedBezelStyle];
    [back setTarget:self];
    [back setAction:@selector(goBack:)];
    [back setAutoresizingMask:NSViewMinYMargin];
    [_browseView addSubview:back];

    _searchField = [[[NSTextField alloc]
        initWithFrame:NSMakeRect(64, top, b.size.width - 64, 22)] autorelease];
    [[_searchField cell] setPlaceholderString:@"buscar músicas…"];
    [_searchField setTarget:self];
    [_searchField setAction:@selector(search:)];
    [_searchField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [_browseView addSubview:_searchField];

    _menuView = [[[GopherMenuView alloc]
        initWithFrame:NSMakeRect(0, 0, b.size.width, top - 6)] autorelease];
    [_menuView setMenuDelegate:self];
    [_menuView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [_browseView addSubview:_menuView];
}

- (void)openSelector:(NSString *)selector push:(BOOL)push
{
    if (selector == nil) {
        return;
    }
    if (push && _currentSelector != nil) {
        [_navStack addObject:_currentSelector];
    }
    [_currentSelector release];
    _currentSelector = [selector copy];

    [_browseRequest cancel];
    [_browseRequest release];
    GopherRequest *req = [GopherRequest requestWithHost:_host port:_port selector:selector];
    [req setDelegate:self];
    _browseRequest = [req retain];
    [req start];
}

- (void)search:(id)sender
{
    NSString *query = [[_searchField stringValue]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([query length] == 0) {
        return;
    }
    NSString *sel = [NSString stringWithFormat:@"%@\t%@", _searchBase, query];
    [self openSelector:sel push:YES];
}

- (void)goBack:(id)sender
{
    if ([_navStack count] == 0) {
        return;
    }
    NSString *prev = [[[_navStack lastObject] retain] autorelease];
    [_navStack removeLastObject];
    [self openSelector:prev push:NO];
}

#pragma mark - GopherMenuViewDelegate (fio 6)

- (void)gopherMenuView:(GopherMenuView *)view didActivateItem:(GopherItem *)item
{
    GopherItemKind kind = [item kind];
    NSString *sel = [item selector];

    if (kind == GopherItemKindSearch) {
        [[_searchField window] makeFirstResponder:_searchField];
        return;
    }
    if (kind == GopherItemKindSound) {
        [_player ensureStreamPlayingURL:_streamURL];
        return;
    }

    // Type-1 (and other clickable items): a play action fires playback and keeps
    // the stream on; everything else is drill-down navigation.
    if ([SpotSelectors isPlayActionSelector:sel playBase:_playBase controlBase:_controlBase]) {
        [_player ensureStreamPlayingURL:_streamURL];
        [self openSelector:sel push:NO];
    } else {
        [self openSelector:sel push:YES];
    }
}

#pragma mark - Now Playing polling

- (void)pollNow
{
    if ([_nowSelector length] == 0) {
        return;
    }
    GopherRequest *req = [GopherRequest requestWithHost:_host port:_port selector:_nowSelector];
    [req setDelegate:self];
    // Keep a handle so we can cancel a poll in flight when we stop; this also
    // supersedes the (already-finished) resolve request stored here.
    [_pollRequest release];
    _pollRequest = [req retain];
    [req start];
}

- (NSString *)nowPlayingFromText:(NSString *)text
{
    NSArray *items = [GopherMenuParser parseMenu:text];
    NSUInteger i, n = [items count];
    for (i = 0; i < n; i++) {
        GopherItem *it = [items objectAtIndex:i];
        if ([it kind] != GopherItemKindInfo) {
            continue;
        }
        NSString *d = [[it displayString] stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceCharacterSet]];
        if ([d length] == 0 || [d isEqualToString:@"Now Playing"]) {
            continue;
        }
        return d;   // first meaningful info line
    }
    return nil;
}

#pragma mark - GopherRequestDelegate

- (void)gopherRequest:(GopherRequest *)request didReceiveData:(NSData *)data
{
    NSString *text = [GopherMenuParser stringFromData:data];

    if (_resolving) {
        NSString *url = [PLSParser firstURLFromPlaylistText:text];
        if ([url length] == 0) {
            [_player showRadinhoMessage:@"gopher-spot: stream não encontrado"];
            [self finishResolving];
            return;
        }
        [_streamURL release];
        _streamURL = [url copy];
        // Hand the resolved stream + ourselves (as control) to the radinho.
        [_player playStreamURL:url title:_title controlDelegate:self];
        // Volume policy: keep the remote (Spotify) pinned at 100% and do all
        // attenuation locally with the radinho's slider (AudioQueue volume).
        [self sendControl:@"vol/100"];
        // Build the embedded browser and seed it at the gopher-spot root.
        [self buildBrowseView];
        [_player setBrowseView:_browseView];
        [self openSelector:_rootSelector push:NO];
        // Begin polling now-playing.
        [self pollNow];
        _pollTimer = [[NSTimer scheduledTimerWithTimeInterval:DT_NOW_POLL_INTERVAL
                                                       target:self
                                                     selector:@selector(pollNow)
                                                     userInfo:nil
                                                      repeats:YES] retain];
        [self finishResolving];
        return;
    }

    if (request == _browseRequest) {
        // A browse fetch: render the menu into the embedded list.
        [_menuView setItems:[GopherMenuParser parseMenu:text]];
        return;
    }

    NSString *np = [self nowPlayingFromText:text];
    if (np != nil) {
        [_player setNowPlayingTitle:np];
    }
}

- (void)gopherRequest:(GopherRequest *)request didFailWithError:(NSError *)error
{
    if (_resolving) {
        // Could not reach gopher-spot to resolve the stream.
        [_player showRadinhoMessage:@"gopher-spot indisponível"];
        [self finishResolving];
    }
    // Poll/browse failures are ignored (transient).
}

@end
