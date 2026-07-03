//
//  StreamPlayerController.h
//  DeToca — fio 2 + fio 5
//
//  The "radinho": a single global floating panel. Two playback modes:
//    - queue mode (fio 2): finite HTTP MP3/AAC files via QTKit; prev/next walk
//      a local PlayQueue.
//    - stream mode (fio 5): an endless live MP3 stream via DTAudioStreamer, with
//      an optional gopher control plane driving transport.
//  A singleton owned by the app, independent of any browser window.
//
//  Gopher-agnostic: transport in stream mode is delegated through the
//  StreamControlDelegate protocol below; the AppDelegate owns the gopher side.
//

#import <Cocoa/Cocoa.h>

@class PlayQueue;
@class QTMovie;
@class DTAudioStreamer;

// Transport for stream mode. The player calls these when its buttons are used;
// the implementer (AppDelegate's gopher-spot control) turns them into gopher
// /spot/control/* requests. Nothing here mentions gopher — the player stays
// protocol-only.
@protocol StreamControlDelegate <NSObject>
- (void)streamControlPlay;
- (void)streamControlPause;
- (void)streamControlNext;
- (void)streamControlPrevious;
@optional
// Called when the player leaves stream mode, so the control can stop polling.
- (void)streamControlWillStop;
@end

@interface StreamPlayerController : NSObject <NSWindowDelegate> {
    NSPanel     *_panel;
    PlayQueue   *_queue;
    QTMovie     *_movie;
    BOOL         _playing;
    float        _volume;
    NSTimer     *_tick;

    int          _mode;              // DTPlayerModeIdle/Queue/Stream
    DTAudioStreamer *_streamer;      // stream mode
    id <StreamControlDelegate> _control;  // retained; nil for a plain stream
    NSString    *_streamURL;         // current stream URL (for ensure-playing)

    NSView      *_transportView;     // holds the compact player controls
    NSView      *_browseView;        // gopher-spot browser area (opaque; not retained)
    BOOL         _expanded;          // panel grown to host the browse area

    NSTextField *_titleLabel;
    NSTextField *_timeLabel;
    NSTextField *_positionLabel;
    NSButton    *_playButton;
    NSButton    *_prevButton;
    NSButton    *_nextButton;
    NSSlider    *_volumeSlider;
}

+ (StreamPlayerController *)sharedController;

// Queue mode (fio 2): finite files.
- (void)playItems:(NSArray *)items atIndex:(NSInteger)index;
- (void)playSingleURL:(NSString *)urlString title:(NSString *)title;

// Stream mode (fio 5): one endless stream, optional gopher control plane.
- (void)playStreamURL:(NSString *)urlString
                title:(NSString *)title
      controlDelegate:(id <StreamControlDelegate>)control;

// Push a now-playing title into the panel (e.g. AppDelegate polling /spot/now).
- (void)setNowPlayingTitle:(NSString *)title;

// Host an opaque browse view below the transport controls (grows the panel);
// pass nil to remove it and shrink back to the compact player. The player stays
// gopher-agnostic — it never inspects the view.
- (void)setBrowseView:(NSView *)view;

// Whether the live stream is currently producing audio.
- (BOOL)isStreamPlaying;

// Whether the player is in live-stream mode (a gopher-spot session is active).
- (BOOL)isStreamActive;

// Show the panel with a plain status message (e.g. "Connecting…") without
// entering any playback mode — used while the radinho is (re)connecting.
- (void)showRadinhoMessage:(NSString *)message;

// Ensure the live stream is playing: resume if paused, or (re)start it from the
// given URL if it stopped. No-op if already playing.
- (void)ensureStreamPlayingURL:(NSString *)urlString;

- (void)showPanel;
- (BOOL)hasQueue;

// Tear down any active playback (queue or stream) and return to idle, stopping
// the stream control plane's polling. Used when reconnecting to a different
// gopher-spot backend after a Preferences change. Leaves the panel on screen.
- (void)stopStreamSession;

// Controls (wired to both the panel buttons and the Playback menu).
- (void)togglePlayPause:(id)sender;
- (void)playNext:(id)sender;
- (void)playPrevious:(id)sender;
- (void)changeVolume:(id)sender;

@end
