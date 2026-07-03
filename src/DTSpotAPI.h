//
//  DTSpotAPI.h
//  DeToca — fio 9, extended fio 10
//
//  Client for the gopher-spot machine API (/spot/api/1) — the source of truth
//  for the player's state and transport. Each endpoint is a Gopher selector
//  fetched over gopher (via GopherRequest). Text endpoints return a `key<TAB>value`
//  document (parsed by DTNowSnapshot / DTTrackItem / DTPlaylistItem); /cover returns
//  raw JPEG bytes. Every command returns a fresh snapshot, so the handler always
//  lands on current state in one round-trip.
//
//  Host/port are read from DTServerPrefs at call time, so the client always
//  targets whatever the Preferences window last saved. Async: handlers fire on
//  the main thread. See gopher-spot API.md for the contract.
//
//  fio 10 adds the rest of the surface: queue (list + add), search, playlists,
//  context play, wake, and cover bytes — plus a monotonic-ts guard on /now so a
//  staler replica (two pods, each with a ~1 s micro-cache) can't rewind the UI.
//

#import <Foundation/Foundation.h>

@class DTNowSnapshot;

// An API error response (api/error/message). `code` is the stable switch key
// (bad_range, no_track, not_found, forbidden, bad_uri, bad_query, no_device,
// upstream); `message` is human English and NOT part of the contract.
// `transport` is our own code for a network failure.
@interface DTSpotAPIError : NSObject {
    NSString *_code;
    NSString *_message;
}
@property (nonatomic, copy) NSString *code;
@property (nonatomic, copy) NSString *message;
+ (DTSpotAPIError *)errorWithCode:(NSString *)code message:(NSString *)message;
@end

// Snapshot handler. Exactly one of (snapshot, error) is non-nil — EXCEPT that a
// /now (or command) whose `ts` regressed is dropped by the monotonic guard, in
// which case BOTH are nil ("no newer state; keep what you have").
typedef void (^DTNowHandler)(DTNowSnapshot *snapshot, DTSpotAPIError *error);

// List handler for /queue, /queue/add and /search. `items` is an array of
// DTTrackItem (empty, never nil, on success). Exactly one of (items, error).
typedef void (^DTTrackListHandler)(NSArray *items, DTSpotAPIError *error);

// Playlists handler. `items` is an array of DTPlaylistItem for this page; `total`
// is Spotify's grand total and `offset` this page's offset (for paging). One of
// (items, error) — `total`/`offset` are 0 on error.
typedef void (^DTPlaylistsHandler)(NSArray *items, NSInteger total,
                                   NSInteger offset, DTSpotAPIError *error);

// Fire-and-forget command handler (context/track play over the human /spot/play).
// `error` is nil on success (the gophermap reply is discarded).
typedef void (^DTPlainHandler)(DTSpotAPIError *error);

// Cover handler. `jpeg` is the raw image bytes, or nil with an error.
typedef void (^DTCoverHandler)(NSData *jpeg, DTSpotAPIError *error);

@interface DTSpotAPI : NSObject {
    id _guard;   // DTSnapshotGuard — monotonic-ts high-water mark across polls
}

// --- State + transport (fio 9) ---
- (void)fetchNow:(DTNowHandler)handler;
- (void)play:(DTNowHandler)handler;
- (void)pause:(DTNowHandler)handler;
- (void)next:(DTNowHandler)handler;
- (void)previous:(DTNowHandler)handler;
- (void)setVolume:(NSInteger)percent handler:(DTNowHandler)handler;   // 0–100
- (void)seekTo:(long long)positionMs handler:(DTNowHandler)handler;

// --- Queue (fio 10) ---
- (void)fetchQueue:(DTTrackListHandler)handler;
- (void)queueAddURI:(NSString *)uri handler:(DTTrackListHandler)handler;   // returns /queue

// --- Search (fio 10) ---
- (void)search:(NSString *)query handler:(DTTrackListHandler)handler;      // capped 10 by Spotify

// --- Playlists (fio 10): list + play-by-context only (no track drill-down) ---
- (void)playlistsAtOffset:(NSInteger)offset handler:(DTPlaylistsHandler)handler;
- (void)playContextURI:(NSString *)contextURI
                offset:(NSInteger)offset
               handler:(DTPlainHandler)handler;
- (void)playTrackURI:(NSString *)trackURI handler:(DTPlainHandler)handler;

// --- Wake (fio 10): transfer playback back onto the gopher-spot device ---
- (void)wake:(DTNowHandler)handler;
- (void)wakeAndPlay:(DTNowHandler)handler;

// --- Cover bytes (fio 10): raw JPEG for an album id at size {64,300,640} ---
- (void)coverForAlbum:(NSString *)albumId size:(NSInteger)size handler:(DTCoverHandler)handler;

// Reset the monotonic-ts guard (e.g. on reconnect to a different backend).
- (void)resetSnapshotGuard;

@end
