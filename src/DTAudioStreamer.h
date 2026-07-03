//
//  DTAudioStreamer.h
//  DeToca — fio 5
//
//  Plays an endless HTTP MP3 stream (Icecast/SHOUTcast) with CoreAudio:
//  AudioFileStream parses the incoming bytes into packets and an AudioQueue
//  renders them. This is what QTKit cannot do — QTMovie only handles finite /
//  progressive files, not live radio.
//
//  Networking + parsing run on a dedicated thread; delegate callbacks are
//  delivered on the main thread. AudioToolbox is available on 10.5, so this is
//  fio-3 (ppc/i386) friendly.
//

#import <Foundation/Foundation.h>

@class DTAudioStreamer;

@protocol DTAudioStreamerDelegate <NSObject>
@optional
- (void)audioStreamerDidStartPlaying:(DTAudioStreamer *)streamer;
- (void)audioStreamer:(DTAudioStreamer *)streamer didFailWithMessage:(NSString *)message;
- (void)audioStreamerDidFinish:(DTAudioStreamer *)streamer;
@end

@interface DTAudioStreamer : NSObject {
    NSString *_urlString;
    id <DTAudioStreamerDelegate> _delegate;   // not retained

    NSThread        *_thread;
    NSURLConnection *_connection;

    void            *_opaque;   // holds the CoreAudio state (see .m)

    float            _volume;
    BOOL             _paused;
    BOOL             _stopped;
    BOOL             _started;
    NSTimeInterval   _startWallClock;
}

@property (nonatomic, assign) id <DTAudioStreamerDelegate> delegate;

- (id)initWithURLString:(NSString *)urlString;

- (void)start;
- (void)stop;               // stops playback and releases everything
- (void)setPaused:(BOOL)paused;
- (BOOL)isPaused;
- (void)setVolume:(float)volume;   // 0.0 .. 1.0

// Seconds since playback actually began (live streams don't have a position).
- (NSTimeInterval)elapsed;

@end
