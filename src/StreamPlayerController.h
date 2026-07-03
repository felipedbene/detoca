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

- (void)showPanel;
- (BOOL)hasQueue;

// Controls (wired to both the panel buttons and the Playback menu).
- (void)togglePlayPause:(id)sender;
- (void)playNext:(id)sender;
- (void)playPrevious:(id)sender;
- (void)changeVolume:(id)sender;

@end
