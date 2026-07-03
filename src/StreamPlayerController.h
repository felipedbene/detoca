//
//  StreamPlayerController.h
//  DeToca — fio 2
//
//  The "radinho": a single global floating panel that plays a queue of audio
//  streams with QTKit. A singleton owned by the app, independent of any menu
//  window — playback survives closing every browser window and stops only when
//  the panel is closed or the app quits.
//
//  Gopher-agnostic: it is handed an array of PlayQueueItem (title + URL) and a
//  start index; it never imports the parser and does not know gopher exists.
//

#import <Cocoa/Cocoa.h>

@class PlayQueue;
@class QTMovie;

@interface StreamPlayerController : NSObject <NSWindowDelegate> {
    NSPanel     *_panel;
    PlayQueue   *_queue;
    QTMovie     *_movie;
    BOOL         _playing;
    float        _volume;
    NSTimer     *_tick;

    NSTextField *_titleLabel;
    NSTextField *_timeLabel;
    NSTextField *_positionLabel;
    NSButton    *_playButton;
    NSButton    *_prevButton;
    NSButton    *_nextButton;
    NSSlider    *_volumeSlider;
}

+ (StreamPlayerController *)sharedController;

// Start a fresh queue (replacing any current one) from PlayQueueItems and play.
- (void)playItems:(NSArray *)items atIndex:(NSInteger)index;

// Convenience: a one-item queue.
- (void)playSingleURL:(NSString *)urlString title:(NSString *)title;

- (void)showPanel;
- (BOOL)hasQueue;

// Controls (wired to both the panel buttons and the Playback menu).
- (void)togglePlayPause:(id)sender;
- (void)playNext:(id)sender;
- (void)playPrevious:(id)sender;
- (void)changeVolume:(id)sender;

@end
