//
//  StreamPlayerController.m
//  DeToca — fio 2
//

#import "StreamPlayerController.h"
#import "PlayQueue.h"
#import "PlayQueueItem.h"
#import "DTAudioStreamer.h"
#import <QTKit/QTKit.h>

#define DT_PLAYER_VOLUME_KEY @"DTPlayerVolume"
#define DT_DEFAULT_VOLUME 0.75f

enum {
    DTPlayerModeIdle = 0,
    DTPlayerModeQueue,    // QTKit finite-file queue (fio 2)
    DTPlayerModeStream    // DTAudioStreamer live stream (fio 5)
};

@interface StreamPlayerController () <DTAudioStreamerDelegate>
- (void)buildPanel;
- (void)ensurePanel;
- (NSTextField *)hudLabelWithFrame:(NSRect)frame size:(CGFloat)size dim:(BOOL)dim;
- (NSButton *)hudButtonWithFrame:(NSRect)frame title:(NSString *)title action:(SEL)action;
- (void)loadAndPlayCurrent;
- (void)checkLoadStateAndPlay;
- (void)teardownMovie;
- (void)teardownStream;
- (void)handleLoadFailure;
- (void)enterIdle;
- (void)startTick;
- (void)stopTick;
- (void)updatePlayButton;
- (void)updateTrackLabels;
- (void)updateTimeLabel;
- (void)showTitle:(NSString *)title;
- (void)loadStateChanged:(NSNotification *)note;
- (void)movieDidEnd:(NSNotification *)note;
@end

static StreamPlayerController *sSharedPlayer = nil;

@implementation StreamPlayerController

+ (StreamPlayerController *)sharedController
{
    if (sSharedPlayer == nil) {
        sSharedPlayer = [[self alloc] init];
    }
    return sSharedPlayer;
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        NSNumber *v = [[NSUserDefaults standardUserDefaults] objectForKey:DT_PLAYER_VOLUME_KEY];
        _volume = (v != nil) ? [v floatValue] : DT_DEFAULT_VOLUME;
        if (_volume < 0.0f) _volume = 0.0f;
        if (_volume > 1.0f) _volume = 1.0f;
    }
    return self;
}

- (void)dealloc
{
    [self teardownMovie];
    [self teardownStream];
    [_queue release];
    [_panel release];
    [super dealloc];
}

#pragma mark - Panel construction (dark HUD)

- (NSTextField *)hudLabelWithFrame:(NSRect)frame size:(CGFloat)size dim:(BOOL)dim
{
    NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [label setBezeled:NO];
    [label setBordered:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setDrawsBackground:NO];
    [label setFont:[NSFont systemFontOfSize:size]];
    [label setTextColor:(dim ? [NSColor colorWithDeviceWhite:0.65 alpha:1.0]
                             : [NSColor colorWithDeviceWhite:0.95 alpha:1.0])];
    [label setStringValue:@""];
    return label;
}

- (NSButton *)hudButtonWithFrame:(NSRect)frame title:(NSString *)title action:(SEL)action
{
    NSButton *b = [[[NSButton alloc] initWithFrame:frame] autorelease];
    [b setTitle:title];
    [b setButtonType:NSMomentaryPushInButton];
    [b setBezelStyle:NSTexturedRoundedBezelStyle];
    [b setTarget:self];
    [b setAction:action];
    [b setFont:[NSFont systemFontOfSize:14.0]];
    return b;
}

- (void)buildPanel
{
    NSRect rect = NSMakeRect(0, 0, 340, 138);
    NSUInteger style = (NSTitledWindowMask | NSClosableWindowMask |
                        NSUtilityWindowMask | NSHUDWindowMask);
    _panel = [[NSPanel alloc] initWithContentRect:rect
                                        styleMask:style
                                          backing:NSBackingStoreBuffered
                                            defer:YES];
    [_panel setTitle:@"Radinho"];
    [_panel setFloatingPanel:YES];
    [_panel setLevel:NSFloatingWindowLevel];
    [_panel setHidesOnDeactivate:NO];
    [_panel setReleasedWhenClosed:NO];
    [_panel setBecomesKeyOnlyIfNeeded:YES];
    [_panel setDelegate:self];

    NSView *c = [_panel contentView];

    _titleLabel = [self hudLabelWithFrame:NSMakeRect(16, 104, 308, 20) size:13.0 dim:NO];
    [[_titleLabel cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [_titleLabel setStringValue:@"Radinho — nothing playing"];
    [c addSubview:_titleLabel];

    _timeLabel = [self hudLabelWithFrame:NSMakeRect(16, 82, 140, 16) size:11.0 dim:YES];
    [_timeLabel setStringValue:@"0:00"];
    [c addSubview:_timeLabel];

    _positionLabel = [self hudLabelWithFrame:NSMakeRect(184, 82, 140, 16) size:11.0 dim:YES];
    [_positionLabel setAlignment:NSRightTextAlignment];
    [c addSubview:_positionLabel];

    _prevButton = [self hudButtonWithFrame:NSMakeRect(94, 44, 48, 30)
                                     title:@"|◀" action:@selector(playPrevious:)];
    [c addSubview:_prevButton];

    _playButton = [self hudButtonWithFrame:NSMakeRect(146, 44, 48, 30)
                                     title:@"▶" action:@selector(togglePlayPause:)];
    [_playButton setKeyEquivalent:@" "];   // space toggles only while the panel is key
    [c addSubview:_playButton];

    _nextButton = [self hudButtonWithFrame:NSMakeRect(198, 44, 48, 30)
                                     title:@"▶|" action:@selector(playNext:)];
    [c addSubview:_nextButton];

    _volumeSlider = [[[NSSlider alloc] initWithFrame:NSMakeRect(16, 14, 308, 20)] autorelease];
    [_volumeSlider setMinValue:0.0];
    [_volumeSlider setMaxValue:1.0];
    [_volumeSlider setFloatValue:_volume];
    [_volumeSlider setTarget:self];
    [_volumeSlider setAction:@selector(changeVolume:)];
    [c addSubview:_volumeSlider];

    [_panel center];
}

- (void)ensurePanel
{
    if (_panel == nil) {
        [self buildPanel];
    }
}

- (void)showPanel
{
    [self ensurePanel];
    [_panel orderFront:self];
}

#pragma mark - Public playback API

- (void)playItems:(NSArray *)items atIndex:(NSInteger)index
{
    if ([items count] == 0) {
        return;
    }
    [self teardownStream];   // leaving stream mode, if any
    _mode = DTPlayerModeQueue;

    [_queue release];
    _queue = [[PlayQueue alloc] initWithItems:items startIndex:index];

    [self ensurePanel];
    [self showPanel];
    [self loadAndPlayCurrent];
}

#pragma mark - Stream mode (fio 5)

- (void)playStreamURL:(NSString *)urlString
                title:(NSString *)title
      controlDelegate:(id <StreamControlDelegate>)control
{
    if ([urlString length] == 0) {
        return;
    }
    // Leave whatever mode we were in.
    [self teardownMovie];
    [self teardownStream];
    _mode = DTPlayerModeStream;

    _control = [control retain];

    [self ensurePanel];
    [self showPanel];

    [self showTitle:([title length] > 0 ? title : @"Live stream")];
    [_positionLabel setStringValue:(_control != nil ? @"live · gopher-spot" : @"live")];
    [_timeLabel setStringValue:@"0:00"];

    _streamer = [[DTAudioStreamer alloc] initWithURLString:urlString];
    [_streamer setDelegate:self];
    [_streamer setVolume:_volume];
    _playing = NO;
    [self updatePlayButton];
    [_streamer start];
}

// Update the title label and force the HUD background under it to repaint —
// the label is non-opaque (drawsBackground:NO), so a shorter new string would
// otherwise leave the tail of the previous one visible.
- (void)showTitle:(NSString *)title
{
    [_titleLabel setStringValue:(title ? title : @"")];
    [[_panel contentView] setNeedsDisplayInRect:[_titleLabel frame]];
}

- (void)setNowPlayingTitle:(NSString *)title
{
    if (_mode == DTPlayerModeStream && [title length] > 0) {
        [self showTitle:title];
    }
}

- (void)teardownStream
{
    if (_control != nil) {
        if ([_control respondsToSelector:@selector(streamControlWillStop)]) {
            [_control streamControlWillStop];
        }
        [_control release];
        _control = nil;
    }
    if (_streamer != nil) {
        [_streamer setDelegate:nil];
        [_streamer stop];
        [_streamer release];
        _streamer = nil;
    }
    [self stopTick];
}

- (void)playSingleURL:(NSString *)urlString title:(NSString *)title
{
    if ([urlString length] == 0) {
        return;
    }
    NSString *t = ([title length] > 0) ? title : urlString;
    PlayQueueItem *item = [PlayQueueItem itemWithTitle:t urlString:urlString];
    [self playItems:[NSArray arrayWithObject:item] atIndex:0];
}

- (BOOL)hasQueue
{
    return (_queue != nil && [_queue count] > 0);
}

#pragma mark - Movie lifecycle

- (void)loadAndPlayCurrent
{
    // Cancel any pending "retry after failure" hop, then replace the movie.
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(loadAndPlayCurrent)
                                               object:nil];
    [self teardownMovie];

    PlayQueueItem *item = [_queue currentItem];
    if (item == nil) {
        [self enterIdle];
        return;
    }

    [self updateTrackLabels];
    [_timeLabel setStringValue:@"0:00"];

    NSURL *url = [NSURL URLWithString:[item urlString]];
    if (url == nil) {
        [self handleLoadFailure];
        return;
    }

    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
        url, QTMovieURLAttribute,
        [NSNumber numberWithBool:YES], QTMovieOpenAsyncOKAttribute,
        nil];
    NSError *error = nil;
    QTMovie *movie = [[QTMovie alloc] initWithAttributes:attrs error:&error];
    if (movie == nil) {
        [self handleLoadFailure];
        return;
    }
    _movie = movie;   // retained by +alloc
    [_movie setVolume:_volume];
    _playing = NO;

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(loadStateChanged:)
               name:QTMovieLoadStateDidChangeNotification object:_movie];
    [nc addObserver:self selector:@selector(movieDidEnd:)
               name:QTMovieDidEndNotification object:_movie];

    // The movie may already be playable (cached/local); don't wait for a change.
    [self checkLoadStateAndPlay];
}

- (void)checkLoadStateAndPlay
{
    if (_movie == nil) {
        return;
    }
    long state = [[_movie attributeForKey:QTMovieLoadStateAttribute] longValue];
    if (state == QTMovieLoadStateError) {
        [self handleLoadFailure];
        return;
    }
    if (state >= QTMovieLoadStatePlayable && !_playing) {
        [_movie play];
        _playing = YES;
        [self startTick];
        [self updatePlayButton];
    }
}

- (void)teardownMovie
{
    [self stopTick];
    if (_movie != nil) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self name:QTMovieLoadStateDidChangeNotification object:_movie];
        [nc removeObserver:self name:QTMovieDidEndNotification object:_movie];
        [_movie stop];
        [_movie release];
        _movie = nil;
    }
    _playing = NO;
}

- (void)handleLoadFailure
{
    // Dead stream: show the failed title briefly, then hop to the next item.
    // No alert — a bad queue must not spam modal dialogs.
    NSString *failed = [[_queue currentItem] title];
    if (failed == nil) {
        failed = @"stream";
    }
    [self teardownMovie];

    PlayQueueItem *next = [_queue advanceToNext];
    if (next != nil) {
        [self showTitle:[NSString stringWithFormat:@"⚠ Skipped “%@” — trying next…", failed]];
        [self updatePlayButton];
        [self performSelector:@selector(loadAndPlayCurrent) withObject:nil afterDelay:0.7];
    } else {
        // End of queue on a failure: go idle but keep the warning visible
        // (do not call -enterIdle, which would overwrite the title).
        [self stopTick];
        _playing = NO;
        [self updatePlayButton];
        [_positionLabel setStringValue:[_queue positionString]];
        [self showTitle:[NSString stringWithFormat:@"⚠ Could not play “%@”", failed]];
    }
}

- (void)enterIdle
{
    [self stopTick];
    _playing = NO;
    [self updatePlayButton];
    [self updateTrackLabels];
}

#pragma mark - Controls

- (void)togglePlayPause:(id)sender
{
    if (_mode == DTPlayerModeStream) {
        // Toggle local audio, and mirror the command to the control plane so
        // the upstream (Spotify) pauses/resumes too.
        BOOL wasPlaying = _playing;
        [_streamer setPaused:wasPlaying];
        _playing = !wasPlaying;
        if (_playing) { [self startTick]; } else { [self stopTick]; }
        [self updatePlayButton];
        if (_control != nil) {
            if (_playing) { [_control streamControlPlay]; }
            else          { [_control streamControlPause]; }
        }
        return;
    }

    // Queue mode.
    if (_movie == nil) {
        // Idle after a finished/failed queue: (re)start the current item.
        if ([_queue currentItem] != nil) {
            [self loadAndPlayCurrent];
        }
        return;
    }
    if (_playing) {
        [_movie stop];       // QTMovie "stop" pauses at the current position
        _playing = NO;
        [self stopTick];
    } else {
        [_movie play];
        _playing = YES;
        [self startTick];
    }
    [self updatePlayButton];
}

- (void)playNext:(id)sender
{
    if (_mode == DTPlayerModeStream) {
        // The stream URL is constant; "next" is a control-plane command.
        if (_control != nil) {
            [_control streamControlNext];
        }
        return;
    }
    PlayQueueItem *next = [_queue advanceToNext];
    if (next != nil) {
        [self loadAndPlayCurrent];
    } else {
        [self enterIdle];    // end of queue: park on the last track
    }
}

- (void)playPrevious:(id)sender
{
    if (_mode == DTPlayerModeStream) {
        if (_control != nil) {
            [_control streamControlPrevious];
        }
        return;
    }
    PlayQueueItem *prev = [_queue goToPrevious];
    if (prev != nil) {
        [self loadAndPlayCurrent];
    }
}

- (void)changeVolume:(id)sender
{
    _volume = [_volumeSlider floatValue];
    if (_movie != nil) {
        [_movie setVolume:_volume];
    }
    if (_streamer != nil) {
        [_streamer setVolume:_volume];
    }
    [[NSUserDefaults standardUserDefaults] setFloat:_volume forKey:DT_PLAYER_VOLUME_KEY];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Notifications

- (void)loadStateChanged:(NSNotification *)note
{
    [self checkLoadStateAndPlay];
}

- (void)movieDidEnd:(NSNotification *)note
{
    [self playNext:self];
}

#pragma mark - DTAudioStreamerDelegate (main thread)

- (void)audioStreamerDidStartPlaying:(DTAudioStreamer *)streamer
{
    if (streamer != _streamer) {
        return;
    }
    _playing = YES;
    [self updatePlayButton];
    [self startTick];
}

- (void)audioStreamer:(DTAudioStreamer *)streamer didFailWithMessage:(NSString *)message
{
    if (streamer != _streamer) {
        return;
    }
    [self stopTick];
    _playing = NO;
    [self updatePlayButton];
    [self showTitle:
        [NSString stringWithFormat:@"⚠ Stream error: %@", (message ? message : @"unknown")]];
}

- (void)audioStreamerDidFinish:(DTAudioStreamer *)streamer
{
    if (streamer != _streamer) {
        return;
    }
    [self stopTick];
    _playing = NO;
    [self updatePlayButton];
}

#pragma mark - UI updates

- (void)updatePlayButton
{
    [_playButton setTitle:(_playing ? @"❙❙" : @"▶")];
}

- (void)updateTrackLabels
{
    PlayQueueItem *item = [_queue currentItem];
    if (item != nil) {
        [self showTitle:[item title]];
    } else {
        [self showTitle:@"Radinho — nothing playing"];
    }
    [_positionLabel setStringValue:[_queue positionString]];
}

- (void)startTick
{
    [self stopTick];
    _tick = [[NSTimer scheduledTimerWithTimeInterval:0.5
                                              target:self
                                            selector:@selector(updateTimeLabel)
                                            userInfo:nil
                                             repeats:YES] retain];
}

- (void)stopTick
{
    if (_tick != nil) {
        [_tick invalidate];
        [_tick release];
        _tick = nil;
    }
}

- (void)updateTimeLabel
{
    NSTimeInterval secs = -1.0;
    if (_mode == DTPlayerModeStream && _streamer != nil) {
        secs = [_streamer elapsed];
    } else if (_movie != nil) {
        QTTime t = [_movie currentTime];
        if (!QTGetTimeInterval(t, &secs)) {
            secs = -1.0;
        }
    }
    if (secs >= 0.0) {
        long total = (long)secs;
        [_timeLabel setStringValue:
            [NSString stringWithFormat:@"%ld:%02ld", total / 60, total % 60]];
    }
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)note
{
    // Closing the panel stops playback entirely.
    [self teardownMovie];
    [self teardownStream];
    [_queue release];
    _queue = nil;
    _mode = DTPlayerModeIdle;
    [self showTitle:@"Radinho — nothing playing"];
    [_positionLabel setStringValue:@""];
    [_timeLabel setStringValue:@"0:00"];
}

@end
