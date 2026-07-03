//
//  DTPlayerWindowController.m
//  DeToca — fio 9
//

#import "DTPlayerWindowController.h"
#import "DTSpotAPI.h"
#import "DTNowSnapshot.h"
#import "DTServerPrefs.h"
#import "PLSParser.h"
#import "DTTheme.h"

#define DT_PW_W 340.0
#define DT_PW_H 160.0
#define DT_STREAM_SELECTOR_KEY @"DTSpotStreamSelector"
#define DT_STREAM_SELECTOR_DEFAULT @"/spot/stream.pls"

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
- (DTNowHandler)applyHandler;
- (NSString *)streamSelector;
@end

@implementation DTPlayerWindowController

- (id)init
{
    self = [super init];
    if (self != nil) {
        _api = [[DTSpotAPI alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [self stopSession];
    [_panel release];
    [_api release];
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

    _titleLabel = [self labelFrame:NSMakeRect(16, 132, 308, 20) size:13.0 dim:NO];
    [[_titleLabel cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [_titleLabel setStringValue:@"Nada tocando"];
    [c addSubview:_titleLabel];

    _subLabel = [self labelFrame:NSMakeRect(16, 114, 308, 16) size:11.0 dim:YES];
    [c addSubview:_subLabel];

    _seekSlider = [[[NSSlider alloc] initWithFrame:NSMakeRect(16, 88, 308, 18)] autorelease];
    [_seekSlider setMinValue:0.0];
    [_seekSlider setMaxValue:1.0];
    [_seekSlider setDoubleValue:0.0];
    [_seekSlider setContinuous:YES];
    [_seekSlider setTarget:self];
    [_seekSlider setAction:@selector(onSeek:)];
    [c addSubview:_seekSlider];

    _elapsedLabel = [self labelFrame:NSMakeRect(16, 70, 120, 14) size:11.0 dim:YES];
    [_elapsedLabel setStringValue:@"0:00"];
    [c addSubview:_elapsedLabel];

    _durationLabel = [self labelFrame:NSMakeRect(204, 70, 120, 14) size:11.0 dim:YES];
    [_durationLabel setAlignment:NSRightTextAlignment];
    [_durationLabel setStringValue:@"0:00"];
    [c addSubview:_durationLabel];

    _prevButton = [self buttonFrame:NSMakeRect(118, 34, 34, 30)
                              title:@"|◀" action:@selector(onPrev:)];
    [c addSubview:_prevButton];
    _playButton = [self buttonFrame:NSMakeRect(154, 34, 34, 30)
                              title:@"▶" action:@selector(onPlayPause:)];
    [c addSubview:_playButton];
    _nextButton = [self buttonFrame:NSMakeRect(190, 34, 34, 30)
                              title:@"▶|" action:@selector(onNext:)];
    [c addSubview:_nextButton];

    NSTextField *vol = [self labelFrame:NSMakeRect(16, 8, 28, 16) size:11.0 dim:YES];
    [vol setStringValue:@"vol"];
    [c addSubview:vol];

    _volumeSlider = [[[NSSlider alloc] initWithFrame:NSMakeRect(46, 6, 140, 18)] autorelease];
    [_volumeSlider setMinValue:0.0];
    [_volumeSlider setMaxValue:100.0];
    [_volumeSlider setDoubleValue:100.0];
    [_volumeSlider setContinuous:NO];   // apply on release (avoid API spam)
    [_volumeSlider setTarget:self];
    [_volumeSlider setAction:@selector(onVolume:)];
    [c addSubview:_volumeSlider];

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
        _pollTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0
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

- (void)pollNow
{
    [_api fetchNow:[self applyHandler]];
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
    if (_last.state != DTPlaybackPlaying || _last.durationMs <= 0) {
        return;
    }
    long long pos = [_last interpolatedPositionMsAtEpochMs:DTNowEpochMs()];
    [_seekSlider setDoubleValue:(double)pos];
    [_elapsedLabel setStringValue:DTFormatMs(pos)];
}

- (void)applySnapshot:(DTNowSnapshot *)snap
{
    [snap retain];
    [_last release];
    _last = snap;

    // Now-playing text.
    if ([snap hasTrack]) {
        NSString *t = snap.track;
        if ([snap.artist length] > 0) {
            t = [NSString stringWithFormat:@"%@ — %@", snap.track, snap.artist];
        }
        [_titleLabel setStringValue:t];
        [_subLabel setStringValue:(snap.album ? snap.album : @"")];
    } else {
        [_titleLabel setStringValue:@"Nada tocando"];
        [_subLabel setStringValue:@""];
    }

    // The now-playing line glows amber while playing.
    [_titleLabel setTextColor:(snap.state == DTPlaybackPlaying
                               ? [DTTheme accent] : [DTTheme textBright])];

    // Play/pause glyph.
    [_playButton setTitle:(snap.state == DTPlaybackPlaying ? @"❙❙" : @"▶")];

    // Seek + time (unless the user is scrubbing).
    long long dur = snap.durationMs;
    [_seekSlider setMaxValue:(dur > 0 ? (double)dur : 1.0)];
    [_durationLabel setStringValue:DTFormatMs(dur)];
    if (!_scrubbing) {
        long long pos = [snap interpolatedPositionMsAtEpochMs:DTNowEpochMs()];
        [_seekSlider setDoubleValue:(double)pos];
        [_elapsedLabel setStringValue:DTFormatMs(pos)];
    }

    // Volume (only when the device reported one, and not while dragging).
    if ([snap hasVolume] && !_scrubbing) {
        [_volumeSlider setDoubleValue:(double)snap.volume];
    }
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
        [_api play:[self applyHandler]];
    }
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
    [_subLabel setStringValue:@""];
    [_seekSlider setDoubleValue:0.0];
    [_elapsedLabel setStringValue:@"0:00"];
    [_durationLabel setStringValue:@"0:00"];
    [_playButton setTitle:@"▶"];
}

@end
