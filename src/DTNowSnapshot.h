//
//  DTNowSnapshot.h
//  DeToca — fio 9
//
//  The parsed /spot/api/1/now snapshot — the machine API's view of what the
//  player should show. The API is a type-0 text document of `key<TAB>value`
//  lines (UTF-8, CRLF); see gopher-spot API.md. This class is the pure,
//  unit-testable parser + model: no gopher, no AppKit. The networked client
//  (DTSpotAPI) turns a raw response into one of these.
//
//  Per the v1 freeze, unknown keys are ignored (forward-compatible), and a
//  client keys off `state` first: track…duration_ms are absent when stopped,
//  and volume is absent when no device reports one.
//

#import <Foundation/Foundation.h>

typedef enum {
    DTPlaybackStopped = 0,
    DTPlaybackPlaying,
    DTPlaybackPaused
} DTPlaybackState;

@interface DTNowSnapshot : NSObject {
    DTPlaybackState _state;
    NSString  *_track;
    NSString  *_artist;
    NSString  *_album;
    NSString  *_trackId;
    long long  _positionMs;
    long long  _durationMs;
    long long  _ts;          // unix epoch ms of the snapshot (for interpolation)
    NSInteger  _volume;      // 0–100, or -1 when the device reported none
    NSInteger  _queueLen;
    NSInteger  _apiVersion;
}

@property (nonatomic, assign) DTPlaybackState state;
@property (nonatomic, copy)   NSString *track;
@property (nonatomic, copy)   NSString *artist;
@property (nonatomic, copy)   NSString *album;
@property (nonatomic, copy)   NSString *trackId;
@property (nonatomic, assign) long long positionMs;
@property (nonatomic, assign) long long durationMs;
@property (nonatomic, assign) long long ts;
@property (nonatomic, assign) NSInteger volume;
@property (nonatomic, assign) NSInteger queueLen;
@property (nonatomic, assign) NSInteger apiVersion;

// Split a raw API response body into a { key: value } dictionary. Each line is
// `key<TAB>value`; a trailing CR is stripped, lines without a TAB are skipped,
// and a repeated key keeps the last value. Pure — the shared primitive used by
// both DTNowSnapshot and the error path.
+ (NSDictionary *)fieldsFromResponse:(NSString *)body;

// Build a snapshot from a raw /now response body (via +fieldsFromResponse:).
// Missing keys default sensibly (state stopped, volume -1, numbers 0).
+ (DTNowSnapshot *)snapshotFromResponse:(NSString *)body;

// Whether a track is loaded (track name present).
- (BOOL)hasTrack;
// Whether the device reported a volume.
- (BOOL)hasVolume;

// Estimated position now, for a smooth progress bar between polls: while
// playing, positionMs + (nowEpochMs − ts), clamped to [0, durationMs]. When not
// playing (or ts unknown), just positionMs.
- (long long)interpolatedPositionMsAtEpochMs:(long long)nowEpochMs;

@end
