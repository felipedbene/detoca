//
//  DTNowSnapshot.m
//  DeToca — fio 9
//

#import "DTNowSnapshot.h"

@implementation DTNowSnapshot

@synthesize state = _state;
@synthesize track = _track;
@synthesize artist = _artist;
@synthesize album = _album;
@synthesize albumId = _albumId;
@synthesize trackId = _trackId;
@synthesize positionMs = _positionMs;
@synthesize durationMs = _durationMs;
@synthesize ts = _ts;
@synthesize volume = _volume;
@synthesize queueLen = _queueLen;
@synthesize apiVersion = _apiVersion;
@synthesize device = _device;

- (id)init
{
    self = [super init];
    if (self != nil) {
        _state = DTPlaybackStopped;
        _volume = -1;   // unknown until a device reports one
    }
    return self;
}

- (void)dealloc
{
    [_track release];
    [_artist release];
    [_album release];
    [_albumId release];
    [_trackId release];
    [super dealloc];
}

+ (NSDictionary *)fieldsFromResponse:(NSString *)body
{
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    if ([body length] == 0) {
        return fields;
    }
    NSArray *lines = [body componentsSeparatedByString:@"\n"];
    NSUInteger i, n = [lines count];
    for (i = 0; i < n; i++) {
        NSString *line = [lines objectAtIndex:i];
        // Strip a trailing CR (CRLF endings) without touching inner characters.
        if ([line hasSuffix:@"\r"]) {
            line = [line substringToIndex:[line length] - 1];
        }
        NSRange tab = [line rangeOfString:@"\t"];
        if (tab.location == NSNotFound) {
            continue;   // not a key<TAB>value line
        }
        NSString *key = [line substringToIndex:tab.location];
        NSString *value = [line substringFromIndex:tab.location + 1];
        if ([key length] > 0) {
            [fields setObject:value forKey:key];   // last value wins
        }
    }
    return fields;
}

+ (DTPlaybackState)stateFromString:(NSString *)s
{
    if ([s isEqualToString:@"playing"]) {
        return DTPlaybackPlaying;
    }
    if ([s isEqualToString:@"paused"]) {
        return DTPlaybackPaused;
    }
    return DTPlaybackStopped;
}

+ (DTDeviceState)deviceFromString:(NSString *)s
{
    if ([s isEqualToString:@"active"]) {
        return DTDeviceActive;
    }
    if ([s isEqualToString:@"idle"]) {
        return DTDeviceIdle;
    }
    return DTDeviceUnknown;   // absent (older server) or unrecognized
}

+ (DTNowSnapshot *)snapshotFromFields:(NSDictionary *)f
{
    DTNowSnapshot *snap = [[[DTNowSnapshot alloc] init] autorelease];

    snap.apiVersion = [[f objectForKey:@"api"] integerValue];
    snap.state = [self stateFromString:[f objectForKey:@"state"]];
    snap.track = [f objectForKey:@"track"];
    snap.artist = [f objectForKey:@"artist"];
    snap.album = [f objectForKey:@"album"];
    snap.albumId = [f objectForKey:@"album_id"];
    snap.trackId = [f objectForKey:@"track_id"];
    snap.positionMs = [[f objectForKey:@"position_ms"] longLongValue];
    snap.durationMs = [[f objectForKey:@"duration_ms"] longLongValue];
    snap.ts = [[f objectForKey:@"ts"] longLongValue];
    snap.queueLen = [[f objectForKey:@"queue_len"] integerValue];
    snap.device = [self deviceFromString:[f objectForKey:@"device"]];

    NSString *vol = [f objectForKey:@"volume"];
    snap.volume = (vol != nil) ? [vol integerValue] : -1;

    return snap;
}

+ (DTNowSnapshot *)snapshotFromResponse:(NSString *)body
{
    return [self snapshotFromFields:[self fieldsFromResponse:body]];
}

- (BOOL)hasTrack
{
    return ([_track length] > 0);
}

- (BOOL)hasVolume
{
    return (_volume >= 0);
}

- (BOOL)deviceIsIdle
{
    return (_device == DTDeviceIdle);
}

- (long long)interpolatedPositionMsAtEpochMs:(long long)nowEpochMs
{
    if (_state != DTPlaybackPlaying || _ts <= 0) {
        return _positionMs;
    }
    long long est = _positionMs + (nowEpochMs - _ts);
    if (est < 0) {
        est = 0;
    }
    if (_durationMs > 0 && est > _durationMs) {
        est = _durationMs;
    }
    return est;
}

@end
