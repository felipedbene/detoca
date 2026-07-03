//
//  DTPlayerWindowController.h
//  DeToca — fio 9
//
//  The WinAmp-style main player window. Unlike the fio-5/6 radinho (a gopher
//  browser with a transport strip bolted on), this is a real player: a marquee
//  now-playing line, an interactive seek bar, transport, and volume — all driven
//  by the /spot/api/1 machine API (DTSpotAPI) as the source of truth. Audio is
//  the Icecast live stream (DTAudioStreamer); the API controls Spotify upstream.
//
//  Polls /now ~1 s and interpolates the seek bar between polls via the
//  snapshot's `ts`. Transport routes to the API (+ mirrors play/pause to the
//  local stream). Search/queue live in the separate playlist window (fio 9 p3).
//

#import <Cocoa/Cocoa.h>
#import "DTAudioStreamer.h"
#import "GopherRequest.h"

@class DTSpotAPI;
@class DTNowSnapshot;

@interface DTPlayerWindowController : NSObject
    <NSWindowDelegate, DTAudioStreamerDelegate, GopherRequestDelegate> {
    NSPanel         *_panel;
    DTSpotAPI       *_api;
    DTAudioStreamer *_streamer;
    DTNowSnapshot   *_last;          // latest snapshot (for interpolation)
    NSString        *_streamURL;     // resolved Icecast URL
    GopherRequest   *_resolveReq;    // PLS resolve in flight

    NSTimer         *_pollTimer;     // /now poll (~1 s)
    NSTimer         *_tickTimer;     // seek-bar animation between polls
    BOOL             _scrubbing;     // user is dragging the seek bar
    BOOL             _resolving;

    NSTextField     *_titleLabel;
    NSTextField     *_subLabel;
    NSTextField     *_elapsedLabel;
    NSTextField     *_durationLabel;
    NSTextField     *_pollLabel;     // honest "(polling…)" indicator
    NSSlider        *_seekSlider;
    NSSlider        *_volumeSlider;
    NSButton        *_prevButton;
    NSButton        *_playButton;
    NSButton        *_nextButton;
}

// Reveal the player, connecting to the current backend (DTServerPrefs) if the
// audio isn't already running. Starts polling.
- (void)show;

// Whether a live session is running (audio started).
- (BOOL)isActive;

// Re-resolve + reconnect to the current backend (after a Preferences change).
- (void)reconnect;

// Transport — used by both the panel buttons and the media keys (fio 8).
- (void)togglePlayPause;
- (void)playNext;
- (void)playPrevious;

@end
