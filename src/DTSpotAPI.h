//
//  DTSpotAPI.h
//  DeToca — fio 9
//
//  Client for the gopher-spot machine API (/spot/api/1) — the source of truth
//  for the player's state and transport. Each endpoint is a type-0 selector
//  fetched over gopher (via GopherRequest); the response is a `key<TAB>value`
//  document parsed by DTNowSnapshot. Every command returns a fresh /now
//  snapshot, so the handler always lands on current state in one round-trip.
//
//  Host/port are read from DTServerPrefs at call time, so the client always
//  targets whatever the Preferences window last saved. Async: handlers fire on
//  the main thread. See gopher-spot API.md for the contract.
//

#import <Foundation/Foundation.h>

@class DTNowSnapshot;

// An API error response (api/error/message). `code` is the stable switch key
// (bad_range, no_track, not_found, upstream); `message` is human English and
// NOT part of the contract. `transport` is our own code for a network failure.
@interface DTSpotAPIError : NSObject {
    NSString *_code;
    NSString *_message;
}
@property (nonatomic, copy) NSString *code;
@property (nonatomic, copy) NSString *message;
+ (DTSpotAPIError *)errorWithCode:(NSString *)code message:(NSString *)message;
@end

// Exactly one of (snapshot, error) is non-nil.
typedef void (^DTNowHandler)(DTNowSnapshot *snapshot, DTSpotAPIError *error);

@interface DTSpotAPI : NSObject

- (void)fetchNow:(DTNowHandler)handler;
- (void)play:(DTNowHandler)handler;
- (void)pause:(DTNowHandler)handler;
- (void)next:(DTNowHandler)handler;
- (void)previous:(DTNowHandler)handler;
- (void)setVolume:(NSInteger)percent handler:(DTNowHandler)handler;   // 0–100
- (void)seekTo:(long long)positionMs handler:(DTNowHandler)handler;

@end
