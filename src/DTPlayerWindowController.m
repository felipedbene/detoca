//
//  DTPlayerWindowController.m
//  DeToca — fio 9
//

#import "DTPlayerWindowController.h"
#import "DTSpotAPI.h"
#import "DTNowSnapshot.h"
#import "DTCoverCache.h"
#import "DTServerPrefs.h"
#import "PLSParser.h"
#import "DTTheme.h"

// Landscape "WinAmp with art" layout: a big square cover on the left, the
// now-playing text + transport filling the right. Fixed size — the simplest
// thing that stays composed (the plan explicitly allows a fixed window).
#define DT_PW_W 452.0
#define DT_PW_H 184.0
#define DT_COVER_SIDE 156.0
#define DT_COVER_SIZE 300   // fetch the 300 cover; it stays crisp scaled to 156
#define DT_STREAM_SELECTOR_KEY @"DTSpotStreamSelector"
#define DT_STREAM_SELECTOR_DEFAULT @"/spot/stream.pls"

NSString * const DTPlayerNowChangedNotification = @"DTPlayerNowChanged";

static long long DTNowEpochMs(void)
{
    return (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
}

static NSString *DTFormatMs(long long ms)
{
    if (ms < 0) {
        ms = 0;
    }
    long long total = ms / 1000;
    return [NSString stringWithFormat:@"%lld:%02lld", total / 60, total % 60];
}

@interface DTPlayerWindowController ()
- (void)buildPanel;
- (NSTextField *)labelFrame:(NSRect)f size:(CGFloat)s dim:(BOOL)dim;
- (void)resolveAndStartAudio;
- (void)startStreamerWithURL:(NSString *)url;
- (void)startPolling;
- (void)stopSession;
- (void)pollNow;
- (void)tick;
- (void)applySnapshot:(DTNowSnapshot *)snap;
- (void)updateCoverForSnapshot:(DTNowSnapshot *)snap;
- (void)updateFooter;
- (void)wakeAndPlay;
- (DTNowHandler)applyHandler;
- (DTNowHandler)wakeHandler;
- (NSString *)streamSelector;
@end

@implementation DTPlayerWindowController

- (id)init
{
    self = [super init];
    if (self != nil) {
        _api = [[DTSpotAPI alloc] init];

        // The cover cache fetches through the API (raw JPEG bytes); the injection
        // keeps DTCoverCache itself pure/off-network for tests.
        _coverCache = [[DTCoverCache alloc] init];
        DTSpotAPI *api = _api;
        [_coverCache setFetcher:^(NSString *albumId, NSInteger size, void (^done)(NSData *)) {
            [api coverForAlbum:albumId size:size handler:^(NSData *jpeg, DTSpotAPIError *err) {
                done(jpeg);
            }];
        }];
    }
    return self;
}

- (void)dealloc
{
    [self stopSession];
    [_panel release];
    [_api release];
    [_coverCache release];
    [_currentAlbumId release];
    [_placeholderCover release];
    [_last release];
    [_streamURL release];
    [super dealloc];
}

#pragma mark - Panel

- (NSTextField *)labelFrame:(NSRect)f size:(CGFloat)s dim:(BOOL)dim
{
    return [DTTheme labelWithFrame:f size:s
                            color:(dim ? [DTTheme textDim] : [DTTheme textBright])];
}

- (NSButton *)buttonFrame:(NSRect)f title:(NSString *)title action:(SEL)action
{
    NSButton *b = [[[NSButton alloc] initWithFrame:f] autorelease];
    [b setTitle:title];
    [b setButtonType:NSMomentaryPushInButton];
    [b setBezelStyle:NSTexturedRoundedBezelStyle];
    [b setFont:[NSFont systemFontOfSize:14.0]];
    [b setTarget:self];
    [b setAction:action];
    return b;
}

- (void)buildPanel
{
    NSRect rect = NSMakeRect(0, 0, DT_PW_W, DT_PW_H);
    NSUInteger style = (NSTitledWindowMask | NSClosableWindowMask |
                        NSUtilityWindowMask | NSHUDWindowMask);
    _panel = [[NSPanel alloc] initWithContentRect:rect
                                        styleMask:style
                                          backing:NSBackingStoreBuffered
                                            defer:YES];
    [_panel setTitle:@"DeToca"];
    [_panel setFloatingPanel:YES];
    [_panel setLevel:NSFloatingWindowLevel];
    [_panel setHidesOnDeactivate:NO];
    [_panel setReleasedWhenClosed:NO];
    [_panel setBecomesKeyOnlyIfNeeded:YES];
    [_panel setDelegate:self];

    NSView *c = [_panel contentView];

    // --- Cover (left): the one colored area; placeholder = amber CRT gopher ---
    _placeholderCover = [[NSApp applicationIconImage] retain];
    _coverView = [[[NSImageView alloc] initWithFrame:
                   NSMakeRect(14, 14, DT_COVER_SIDE, DT_COVER_SIDE)] autorelease];
    [_coverView setImageFrameStyle:NSImageFrameNone];
    [_coverView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [_coverView setImageAlignment:NSImageAlignCenter];
    [_coverView setEditable:NO];
    [_coverView setImage:_placeholderCover];
    [c addSubview:_coverView];

    // Right column geometry.
    CGFloat rx = 14 + DT_COVER_SIDE + 14;     // 184
    CGFloat rw = DT_PW_W - rx - 14;           // 254

    // --- Title + artist on SEPARATE lines (tail-truncated, no middle chop) ---
    _titleLabel = [self labelFrame:NSMakeRect(rx, 150, rw, 20) size:13.0 dim:NO];
    [[_titleLabel cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [_titleLabel setStringValue:@"Nada tocando"];
    [c addSubview:_titleLabel];

    _subLabel = [self labelFrame:NSMakeRect(rx, 130, rw, 16) size:11.0 dim:YES];
    [[_subLabel cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [c addSubview:_subLabel];

    // --- Seek + time ---
    _seekSlider = [[[NSSlider alloc] initWithFrame:NSMakeRect(rx, 98, rw, 18)] autorelease];
    [_seekSlider setMinValue:0.0];
    [_seekSlider setMaxValue:1.0];
    [_seekSlider setDoubleValue:0.0];
    [_seekSlider setContinuous:YES];
    [_seekSlider setTarget:self];
    [_seekSlider setAction:@selector(onSeek:)];
    [c addSubview:_seekSlider];

    _elapsedLabel = [self labelFrame:NSMakeRect(rx, 82, 110, 13) size:11.0 dim:YES];
    [_elapsedLabel setStringValue:@"–:–"];
    [c addSubview:_elapsedLabel];

    _durationLabel = [self labelFrame:NSMakeRect(rx + rw - 110, 82, 110, 13) size:11.0 dim:YES];
    [_durationLabel setAlignment:NSRightTextAlignment];
    [_durationLabel setStringValue:@"–:–"];
    [c addSubview:_durationLabel];

    // --- Transport, centered under the seek bar ---
    CGFloat bcx = rx + rw / 2.0;              // right-column center
    _prevButton = [self buttonFrame:NSMakeRect(bcx - 57, 46, 34, 30)
                              title:@"|◀" action:@selector(onPrev:)];
    [c addSubview:_prevButton];
    _playButton = [self buttonFrame:NSMakeRect(bcx - 17, 46, 34, 30)
                              title:@"▶" action:@selector(onPlayPause:)];
    [c addSubview:_playButton];
    _nextButton = [self buttonFrame:NSMakeRect(bcx + 23, 46, 34, 30)
                              title:@"▶|" action:@selector(onNext:)];
    [c addSubview:_nextButton];

    // --- Volume + status row ---
    NSTextField *vol = [self labelFrame:NSMakeRect(rx, 16, 26, 16) size:11.0 dim:YES];
    [vol setStringValue:@"vol"];
    [c addSubview:vol];

    _volumeSlider = [[[NSSlider alloc] initWithFrame:NSMakeRect(rx + 28, 14, 120, 18)] autorelease];
    [_volumeSlider setMinValue:0.0];
    [_volumeSlider setMaxValue:100.0];
    [_volumeSlider setDoubleValue:100.0];
    [_volumeSlider setContinuous:NO];   // apply on release (avoid API spam)
    [_volumeSlider setTarget:self];
    [_volumeSlider setAction:@selector(onVolume:)];
    [c addSubview:_volumeSlider];

    // Honest polling / device indicator, bottom-right of the column.
    _pollLabel = [self labelFrame:NSMakeRect(rx + rw - 130, 15, 130, 12) size:9.0 dim:YES];
    [_pollLabel setAlignment:NSRightTextAlignment];
    [_pollLabel setTextColor:[DTTheme textMuted]];
    [c addSubview:_pollLabel];

    [_panel center];
}

- (void)ensurePanel
{
    if (_panel == nil) {
        [self buildPanel];
    }
}

#pragma mark - Public

- (void)show
{
    [self ensurePanel];
    [_panel orderFront:self];
    if (![self isActive] && !_resolving) {
        [_subLabel setStringValue:@"Conectando…"];
        [self resolveAndStartAudio];
    }
    [self startPolling];
    [self pollNow];
}

- (BOOL)isActive
{
    return (_streamer != nil);
}

- (void)reconnect
{
    [self stopSession];
    // A different backend has its own ts timeline and its own cover for whatever
    // is playing: forget the guard's high-water mark and the shown album.
    [_api resetSnapshotGuard];
    [_currentAlbumId release];
    _currentAlbumId = nil;
    [_coverView setImage:_placeholderCover];
    [self show];
}

#pragma mark - Stream resolution (PLS over gopher)

- (NSString *)streamSelector
{
    NSString *sel = [[NSUserDefaults standardUserDefaults]
                     objectForKey:DT_STREAM_SELECTOR_KEY];
    return ([sel length] > 0) ? sel : DT_STREAM_SELECTOR_DEFAULT;
}

- (void)resolveAndStartAudio
{
    if (_resolving) {
        return;
    }
    _resolving = YES;
    [_resolveReq cancel];
    [_resolveReq release];
    _resolveReq = [[GopherRequest requestWithHost:[DTServerPrefs host]
                                             port:[DTServerPrefs port]
                                         selector:[self streamSelector]] retain];
    [_resolveReq setDelegate:self];
    [_resolveReq start];
}

- (void)gopherRequest:(GopherRequest *)request didReceiveData:(NSData *)data
{
    if (request != _resolveReq) {
        return;
    }
    _resolving = NO;
    NSString *body = [[[NSString alloc] initWithData:data
                                            encoding:NSUTF8StringEncoding] autorelease];
    NSString *url = [PLSParser firstURLFromPlaylistText:body];
    if ([url length] == 0) {
        [_subLabel setStringValue:@"stream indisponível"];
        return;
    }
    [self startStreamerWithURL:url];
}

- (void)gopherRequest:(GopherRequest *)request didFailWithError:(NSError *)error
{
    if (request != _resolveReq) {
        return;
    }
    _resolving = NO;
    [_subLabel setStringValue:@"erro ao conectar"];
}

- (void)startStreamerWithURL:(NSString *)url
{
    [_streamURL release];
    _streamURL = [url copy];

    [_streamer setDelegate:nil];
    [_streamer stop];
    [_streamer release];
    _streamer = [[DTAudioStreamer alloc] initWithURLString:url];
    [_streamer setDelegate:self];
    [_streamer setVolume:1.0];   // loudness is controlled via the API device volume
    [_streamer start];
}

#pragma mark - Polling

- (void)startPolling
{
    if (_pollTimer == nil) {
        _pollTimer = [[NSTimer scheduledTimerWithTimeInterval:2.0
                                                       target:self
                                                     selector:@selector(pollNow)
                                                     userInfo:nil
                                                      repeats:YES] retain];
    }
    if (_tickTimer == nil) {
        _tickTimer = [[NSTimer scheduledTimerWithTimeInterval:0.25
                                                       target:self
                                                     selector:@selector(tick)
                                                     userInfo:nil
                                                      repeats:YES] retain];
    }
}

- (void)stopSession
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(clearPollLabel)
                                               object:nil];
    [_pollTimer invalidate];
    [_pollTimer release];
    _pollTimer = nil;
    [_tickTimer invalidate];
    [_tickTimer release];
    _tickTimer = nil;

    [_resolveReq cancel];
    [_resolveReq release];
    _resolveReq = nil;
    _resolving = NO;

    [_streamer setDelegate:nil];
    [_streamer stop];
    [_streamer release];
    _streamer = nil;
}

- (void)clearPollLabel
{
    [_pollLabel setStringValue:@""];
}

- (void)pollNow
{
    // Be honest that state is polled (~2 s), not live: pulse "(polling…)" each
    // cycle, visible long enough to read even though the LAN round-trip is fast.
    // But when the radio is asleep (device idle), the footer carries a persistent
    // "play pra acordar" nudge instead — don't stomp it with the pulse.
    if (!(_last != nil && [_last deviceIsIdle])) {
        [_pollLabel setStringValue:@"(polling…)"];
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(clearPollLabel)
                                                   object:nil];
        [self performSelector:@selector(clearPollLabel) withObject:nil afterDelay:0.8];
    }
    [_api fetchNow:[self applyHandler]];
}

// The footer doubles as the device-state indicator: when gopher-spot isn't the
// current player (device idle), the audio stream carries nothing, so nudge the
// user to press play (which wakes it). Otherwise it's the transient poll pulse.
- (void)updateFooter
{
    if (_last != nil && [_last deviceIsIdle]) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(clearPollLabel)
                                                   object:nil];
        [_pollLabel setStringValue:@"rádio dormindo — play pra acordar"];
        [_pollLabel setTextColor:[DTTheme accent]];
    } else {
        [_pollLabel setTextColor:[DTTheme textMuted]];
    }
}

- (DTNowHandler)applyHandler
{
    DTPlayerWindowController *me = self;
    return [[^(DTNowSnapshot *snap, DTSpotAPIError *error) {
        if (snap != nil) {
            [me applySnapshot:snap];
        }
    } copy] autorelease];
}

- (void)tick
{
    if (_last == nil || _scrubbing) {
        return;
    }
    // Advance the clock only while music is actually playing.
    if (![_last hasTrack] || _last.state != DTPlaybackPlaying || _last.durationMs <= 0) {
        return;
    }
    long long pos = [_last interpolatedPositionMsAtEpochMs:DTNowEpochMs()];
    [_seekSlider setDoubleValue:(double)pos];
    [_elapsedLabel setStringValue:DTFormatMs(pos)];
}

- (void)applySnapshot:(DTNowSnapshot *)snap
{
    // Detect a track/queue change vs. the previous snapshot before we replace it,
    // so the playlist window can refresh "up next" off this same poll.
    NSString *oldTrackId = [[_last.trackId retain] autorelease];
    NSInteger oldQueueLen = (_last != nil) ? _last.queueLen : -1;

    [snap retain];
    [_last release];
    _last = snap;

    BOOL trackChanged = ![oldTrackId isEqualToString:snap.trackId] &&
                        !(oldTrackId == nil && snap.trackId == nil);
    if (trackChanged || oldQueueLen != snap.queueLen) {
        [[NSNotificationCenter defaultCenter]
            postNotificationName:DTPlayerNowChangedNotification object:self];
    }

    // Now-playing text — title and artist on their own lines (the cover carries
    // the album, so no album line and no middle-truncation of a joined string).
    if ([snap hasTrack]) {
        [_titleLabel setStringValue:(snap.track ? snap.track : @"")];
        [_subLabel setStringValue:(snap.artist ? snap.artist : @"")];
    } else {
        [_titleLabel setStringValue:@"Nada tocando"];
        [_subLabel setStringValue:@""];
    }

    // The now-playing line glows amber while playing.
    [_titleLabel setTextColor:(snap.state == DTPlaybackPlaying
                               ? [DTTheme accent] : [DTTheme textBright])];

    // Album cover (fetched only when album_id changes; placeholder otherwise).
    [self updateCoverForSnapshot:snap];

    // Device-state footer (idle => "play pra acordar").
    [self updateFooter];

    // Play/pause glyph.
    [_playButton setTitle:(snap.state == DTPlaybackPlaying ? @"❙❙" : @"▶")];

    // Time only counts when there IS music — with nothing loaded, show no clock
    // and a dead seek bar rather than a fake 0:00.
    if (![snap hasTrack]) {
        [_seekSlider setEnabled:NO];
        [_seekSlider setDoubleValue:0.0];
        [_elapsedLabel setStringValue:@"–:–"];
        [_durationLabel setStringValue:@"–:–"];
    } else if (!_scrubbing) {
        long long dur = snap.durationMs;
        [_seekSlider setEnabled:YES];
        [_seekSlider setMaxValue:(dur > 0 ? (double)dur : 1.0)];
        [_durationLabel setStringValue:DTFormatMs(dur)];
        long long pos = [snap interpolatedPositionMsAtEpochMs:DTNowEpochMs()];
        [_seekSlider setDoubleValue:(double)pos];
        [_elapsedLabel setStringValue:DTFormatMs(pos)];
    }

    // Volume (only when the device reported one, and not while dragging).
    if ([snap hasVolume] && !_scrubbing) {
        [_volumeSlider setDoubleValue:(double)snap.volume];
    }
}

- (void)updateCoverForSnapshot:(DTNowSnapshot *)snap
{
    NSString *albumId = [snap hasTrack] ? snap.albumId : nil;

    // No art available (nothing loaded, or an item with no album): placeholder.
    if ([albumId length] == 0) {
        if (_currentAlbumId != nil) {
            [_currentAlbumId release];
            _currentAlbumId = nil;
        }
        [_coverView setImage:_placeholderCover];
        return;
    }

    // Same album as what's shown: never refetch.
    if ([albumId isEqualToString:_currentAlbumId]) {
        return;
    }
    [_currentAlbumId release];
    _currentAlbumId = [albumId copy];

    [_coverCache coverForAlbum:albumId size:DT_COVER_SIZE handler:^(NSData *jpeg) {
        // Drop the result if the album changed again while this fetch was in
        // flight (compare by value against the album now showing).
        if (![albumId isEqualToString:_currentAlbumId]) {
            return;
        }
        NSImage *img = ([jpeg length] > 0)
            ? [[[NSImage alloc] initWithData:jpeg] autorelease] : nil;
        [_coverView setImage:(img ? img : _placeholderCover)];
    }];
}

#pragma mark - Transport (buttons + media keys)

- (void)ensureAudio
{
    if (_streamer == nil && !_resolving) {
        [self resolveAndStartAudio];
    } else if (_streamer != nil) {
        [_streamer setPaused:NO];
    }
}

- (void)togglePlayPause
{
    BOOL playing = (_last != nil && _last.state == DTPlaybackPlaying);
    if (playing) {
        [_streamer setPaused:YES];
        [_playButton setTitle:@"▶"];
        [_api pause:[self applyHandler]];
    } else {
        [self ensureAudio];
        [_playButton setTitle:@"❙❙"];
        // If the radio drifted to another device (or librespot dropped and the
        // device fell idle), a plain play won't move audio back to our stream.
        // Transfer + resume with wake?play=1 instead. This is the S3 case: ffmpeg
        // respawns in ~4 s but the device falls idle — pressing play revives it.
        if (_last != nil && [_last deviceIsIdle]) {
            [self wakeAndPlay];
        } else {
            [_api play:[self applyHandler]];
        }
    }
}

- (void)wakeAndPlay
{
    [_pollLabel setStringValue:@"acordando o rádio…"];
    [_pollLabel setTextColor:[DTTheme accent]];
    [_api wakeAndPlay:[self wakeHandler]];
}

- (DTNowHandler)wakeHandler
{
    DTPlayerWindowController *me = self;
    return [[^(DTNowSnapshot *snap, DTSpotAPIError *error) {
        if (error != nil) {
            // no_device: librespot is down, nothing to wake — say so honestly.
            if ([[error code] isEqualToString:@"no_device"]) {
                [me->_pollLabel setStringValue:@"rádio fora do ar"];
                [me->_pollLabel setTextColor:[DTTheme error]];
            }
            return;
        }
        if (snap != nil) {
            [me applySnapshot:snap];
        }
    } copy] autorelease];
}

- (void)playNext
{
    [_api next:[self applyHandler]];
}

- (void)playPrevious
{
    [_api previous:[self applyHandler]];
}

- (void)onPlayPause:(id)sender { [self togglePlayPause]; }
- (void)onNext:(id)sender      { [self playNext]; }
- (void)onPrev:(id)sender      { [self playPrevious]; }

- (void)onSeek:(id)sender
{
    NSEvent *e = [_panel currentEvent];
    long long ms = (long long)[_seekSlider doubleValue];
    if ([e type] == NSLeftMouseUp) {
        _scrubbing = NO;
        [_api seekTo:ms handler:[self applyHandler]];
    } else {
        _scrubbing = YES;
        [_elapsedLabel setStringValue:DTFormatMs(ms)];
    }
}

- (void)onVolume:(id)sender
{
    [_api setVolume:(NSInteger)[_volumeSlider doubleValue] handler:[self applyHandler]];
}

#pragma mark - DTAudioStreamerDelegate

- (void)audioStreamerDidStartPlaying:(DTAudioStreamer *)streamer
{
    if (streamer == _streamer && [[_subLabel stringValue] length] == 0) {
        // leave the album/now-playing text as the poll set it
    }
}

- (void)audioStreamer:(DTAudioStreamer *)streamer didFailWithMessage:(NSString *)message
{
    if (streamer == _streamer) {
        [_subLabel setStringValue:@"erro no stream"];
    }
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)note
{
    [self stopSession];
    [_titleLabel setStringValue:@"Nada tocando"];
    [_titleLabel setTextColor:[DTTheme textBright]];
    [_subLabel setStringValue:@""];
    [_pollLabel setStringValue:@""];
    [_seekSlider setEnabled:NO];
    [_seekSlider setDoubleValue:0.0];
    [_elapsedLabel setStringValue:@"–:–"];
    [_durationLabel setStringValue:@"–:–"];
    [_playButton setTitle:@"▶"];
    [_currentAlbumId release];
    _currentAlbumId = nil;
    [_coverView setImage:_placeholderCover];
}

@end
