//
//  GopherSpotControl.m
//  DeToca — fio 5
//

#import "GopherSpotControl.h"
#import "GopherItem.h"
#import "GopherMenuParser.h"
#import "PLSParser.h"

#define DT_NOW_POLL_INTERVAL 6.0

@interface GopherSpotControl ()
- (void)sendControl:(NSString *)command;
- (void)fireCommand:(NSString *)command;
- (void)pollNow;
- (NSString *)nowPlayingFromText:(NSString *)text;
- (void)finishResolving;
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
    }
    return self;
}

- (void)dealloc
{
    [_host release];
    [_streamSelector release];
    [_controlBase release];
    [_nowSelector release];
    [_title release];
    [_pollRequest release];
    [_pollTimer release];
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
            [self finishResolving];
            return;
        }
        // Hand the resolved stream + ourselves (as control) to the radinho.
        [_player playStreamURL:url title:_title controlDelegate:self];
        // Volume policy: keep the remote (Spotify) pinned at 100% and do all
        // attenuation locally with the radinho's slider (AudioQueue volume).
        [self sendControl:@"vol/100"];
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

    NSString *np = [self nowPlayingFromText:text];
    if (np != nil) {
        [_player setNowPlayingTitle:np];
    }
}

- (void)gopherRequest:(GopherRequest *)request didFailWithError:(NSError *)error
{
    if (_resolving) {
        // Could not fetch the playlist; give up quietly.
        [self finishResolving];
    }
    // Poll failures are ignored (transient).
}

@end
