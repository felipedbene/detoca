//
//  SpotAPITests.m
//  DeToca — OCUnit tests for the fio-9 machine-API model layer (DTNowSnapshot).
//  Pure Foundation; the networked DTSpotAPI is not exercised here.
//

#import <SenTestingKit/SenTestingKit.h>

#import "DTNowSnapshot.h"
#import "DTTrackItem.h"
#import "DTPlaylistItem.h"
#import "DTSnapshotGuard.h"
#import "DTCoverCache.h"

@interface SpotAPITests : SenTestCase
@end

@implementation SpotAPITests

#pragma mark - fieldsFromResponse

- (void)testFieldsBasic
{
    NSDictionary *f = [DTNowSnapshot fieldsFromResponse:
                       @"api\t1\r\nstate\tplaying\r\n"];
    STAssertEqualObjects([f objectForKey:@"api"], @"1", @"api parsed");
    STAssertEqualObjects([f objectForKey:@"state"], @"playing", @"state parsed");
}

- (void)testFieldsStripCROnlyAtLineEnd
{
    // A value with inner characters is preserved; only the trailing CR goes.
    NSDictionary *f = [DTNowSnapshot fieldsFromResponse:@"track\tName With Spaces\r\n"];
    STAssertEqualObjects([f objectForKey:@"track"], @"Name With Spaces", @"value intact");
}

- (void)testFieldsSkipNoTabLines
{
    NSDictionary *f = [DTNowSnapshot fieldsFromResponse:@"garbage line\r\nkey\tval\r\n"];
    STAssertNil([f objectForKey:@"garbage line"], @"non key<TAB>value line skipped");
    STAssertEqualObjects([f objectForKey:@"key"], @"val", @"real line kept");
}

- (void)testFieldsLastWins
{
    NSDictionary *f = [DTNowSnapshot fieldsFromResponse:@"k\ta\r\nk\tb\r\n"];
    STAssertEqualObjects([f objectForKey:@"k"], @"b", @"repeated key keeps last");
}

- (void)testFieldsEmpty
{
    STAssertEquals([[DTNowSnapshot fieldsFromResponse:@""] count], (NSUInteger)0,
                   @"empty body -> empty dict");
    STAssertEquals([[DTNowSnapshot fieldsFromResponse:nil] count], (NSUInteger)0,
                   @"nil body -> empty dict");
}

#pragma mark - snapshotFromResponse

- (void)testSnapshotPlaying
{
    // The canonical example from gopher-spot API.md.
    NSString *body =
        @"api\t1\r\nstate\tplaying\r\ntrack\tConstrução\r\n"
        @"artist\tChico Buarque\r\nalbum\tConstrução\r\n"
        @"track_id\t3FIuBxOxuQ6kYy8JO0gq2a\r\nposition_ms\t26221\r\n"
        @"duration_ms\t383626\r\nvolume\t100\r\nqueue_len\t0\r\nts\t1783105644431\r\n";
    DTNowSnapshot *s = [DTNowSnapshot snapshotFromResponse:body];

    STAssertEquals(s.apiVersion, (NSInteger)1, @"api");
    STAssertEquals(s.state, DTPlaybackPlaying, @"state playing");
    STAssertEqualObjects(s.track, @"Construção", @"UTF-8 track name intact");
    STAssertEqualObjects(s.artist, @"Chico Buarque", @"artist");
    STAssertEqualObjects(s.trackId, @"3FIuBxOxuQ6kYy8JO0gq2a", @"track id");
    STAssertEquals(s.positionMs, (long long)26221, @"position");
    STAssertEquals(s.durationMs, (long long)383626, @"duration");
    STAssertEquals(s.volume, (NSInteger)100, @"volume");
    STAssertEquals(s.queueLen, (NSInteger)0, @"queue len");
    STAssertEquals(s.ts, (long long)1783105644431LL, @"ts (64-bit epoch ms)");
    STAssertTrue([s hasTrack], @"has track");
    STAssertTrue([s hasVolume], @"has volume");
}

- (void)testSnapshotStopped
{
    DTNowSnapshot *s = [DTNowSnapshot snapshotFromResponse:
                        @"api\t1\r\nstate\tstopped\r\nqueue_len\t0\r\nts\t123\r\n"];
    STAssertEquals(s.state, DTPlaybackStopped, @"stopped");
    STAssertFalse([s hasTrack], @"no track when stopped");
    STAssertFalse([s hasVolume], @"no volume reported -> hasVolume NO");
    STAssertEquals(s.volume, (NSInteger)-1, @"absent volume is -1");
}

- (void)testSnapshotPaused
{
    DTNowSnapshot *s = [DTNowSnapshot snapshotFromResponse:@"state\tpaused\r\n"];
    STAssertEquals(s.state, DTPlaybackPaused, @"paused");
}

- (void)testSnapshotIgnoresUnknownKeys
{
    // Forward-compat: a v1 response may grow keys; the client must not choke.
    DTNowSnapshot *s = [DTNowSnapshot snapshotFromResponse:
                        @"api\t1\r\nstate\tplaying\r\ntrack\tX\r\ncover_url\thttp://x/y.png\r\n"];
    STAssertEquals(s.state, DTPlaybackPlaying, @"still parses known keys");
    STAssertEqualObjects(s.track, @"X", @"track parsed despite unknown key");
}

#pragma mark - interpolation

- (void)testInterpolationWhilePlaying
{
    DTNowSnapshot *s = [DTNowSnapshot snapshotFromResponse:
        @"state\tplaying\r\nposition_ms\t1000\r\nduration_ms\t200000\r\nts\t5000\r\n"];
    // 1500 ms elapsed since the snapshot -> position advances the same amount.
    STAssertEquals([s interpolatedPositionMsAtEpochMs:6500], (long long)2500,
                   @"interpolates forward while playing");
}

- (void)testInterpolationClampsToDuration
{
    DTNowSnapshot *s = [DTNowSnapshot snapshotFromResponse:
        @"state\tplaying\r\nposition_ms\t199000\r\nduration_ms\t200000\r\nts\t1000\r\n"];
    STAssertEquals([s interpolatedPositionMsAtEpochMs:1000000], (long long)200000,
                   @"never exceeds duration");
}

- (void)testInterpolationPausedIsFrozen
{
    DTNowSnapshot *s = [DTNowSnapshot snapshotFromResponse:
        @"state\tpaused\r\nposition_ms\t42000\r\nduration_ms\t200000\r\nts\t1000\r\n"];
    STAssertEquals([s interpolatedPositionMsAtEpochMs:999999], (long long)42000,
                   @"paused position does not advance");
}

#pragma mark - fio 10: /now album_id + device

- (void)testSnapshotAlbumIdAndDeviceActive
{
    DTNowSnapshot *s = [DTNowSnapshot snapshotFromResponse:
        @"api\t1\r\nstate\tplaying\r\ntrack\tX\r\nalbum_id\t3AB\r\ndevice\tactive\r\nts\t7\r\n"];
    STAssertEqualObjects(s.albumId, @"3AB", @"album_id parsed");
    STAssertEquals(s.device, DTDeviceActive, @"device active");
    STAssertFalse([s deviceIsIdle], @"active is not idle");
}

- (void)testSnapshotDeviceIdle
{
    DTNowSnapshot *s = [DTNowSnapshot snapshotFromResponse:
        @"api\t1\r\nstate\tplaying\r\ndevice\tidle\r\nts\t7\r\n"];
    STAssertEquals(s.device, DTDeviceIdle, @"device idle");
    STAssertTrue([s deviceIsIdle], @"idle reported");
}

- (void)testSnapshotDeviceAbsentIsUnknown
{
    // An older server that never emits `device` -> unknown, and not idle.
    DTNowSnapshot *s = [DTNowSnapshot snapshotFromResponse:@"api\t1\r\nstate\tstopped\r\n"];
    STAssertEquals(s.device, DTDeviceUnknown, @"absent device -> unknown");
    STAssertFalse([s deviceIsIdle], @"unknown is not idle");
    STAssertNil(s.albumId, @"album_id absent -> nil");
}

#pragma mark - fio 10: track list parsing (queue / search / playlist tracks)

- (void)testTrackListParsesItems
{
    NSString *body =
        @"api\t1\r\nqueue_len\t2\r\n"
        @"item.0.uri\tspotify:track:aaa\r\nitem.0.track\tConstrução\r\n"
        @"item.0.artist\tChico Buarque\r\nitem.0.album_id\talb1\r\nitem.0.duration_ms\t383626\r\n"
        @"item.1.uri\tspotify:track:bbb\r\nitem.1.track\tCotidiano\r\n"
        @"item.1.artist\tChico\r\nitem.1.duration_ms\t100000\r\n"
        @"ts\t123\r\n";
    NSArray *items = [DTTrackItem itemsFromResponse:body];
    STAssertEquals([items count], (NSUInteger)2, @"two items");

    DTTrackItem *a = [items objectAtIndex:0];
    STAssertEqualObjects(a.uri, @"spotify:track:aaa", @"uri intact (colons)");
    STAssertEqualObjects(a.track, @"Construção", @"UTF-8 track name intact");
    STAssertEqualObjects(a.artist, @"Chico Buarque", @"artist");
    STAssertEqualObjects(a.albumId, @"alb1", @"album_id");
    STAssertEquals(a.durationMs, (long long)383626, @"duration");

    DTTrackItem *b = [items objectAtIndex:1];
    STAssertEqualObjects(b.track, @"Cotidiano", @"second track");
    STAssertNil(b.albumId, @"absent album_id -> nil");
}

- (void)testTrackListEmpty
{
    NSArray *items = [DTTrackItem itemsFromResponse:@"api\t1\r\nqueue_len\t0\r\nts\t1\r\n"];
    STAssertNotNil(items, @"empty list is an array, not nil");
    STAssertEquals([items count], (NSUInteger)0, @"no item.* lines -> empty");
}

- (void)testTrackListStopsAtFirstGap
{
    // Only item.0 present -> exactly one, even if a later stray index exists.
    NSString *body =
        @"item.0.uri\tspotify:track:a\r\nitem.0.track\tOne\r\n"
        @"item.2.uri\tspotify:track:c\r\nitem.2.track\tThree\r\n";
    NSArray *items = [DTTrackItem itemsFromResponse:body];
    STAssertEquals([items count], (NSUInteger)1, @"contiguous scan stops at the gap");
}

#pragma mark - fio 10: playlist list parsing

- (void)testPlaylistListParses
{
    NSString *body =
        @"api\t1\r\nresult_len\t2\r\ntotal\t155\r\noffset\t0\r\n"
        @"item.0.id\tpl1\r\nitem.0.name\tRock Nacional\r\nitem.0.tracks_len\t42\r\n"
        @"item.1.id\tpl2\r\nitem.1.name\tSambas\r\nitem.1.tracks_len\t0\r\n"
        @"ts\t9\r\n";
    NSArray *items = [DTPlaylistItem itemsFromResponse:body];
    STAssertEquals([items count], (NSUInteger)2, @"two playlists");

    DTPlaylistItem *p = [items objectAtIndex:0];
    STAssertEqualObjects(p.playlistId, @"pl1", @"id");
    STAssertEqualObjects(p.name, @"Rock Nacional", @"name");
    STAssertEquals(p.tracksLen, (NSInteger)42, @"tracks_len");
    STAssertEqualObjects([p contextURI], @"spotify:playlist:pl1", @"context uri");

    DTPlaylistItem *q = [items objectAtIndex:1];
    STAssertEquals(q.tracksLen, (NSInteger)0, @"dev-mode 0 tracks");
}

- (void)testPlaylistListEmpty
{
    NSArray *items = [DTPlaylistItem itemsFromResponse:
                      @"api\t1\r\nresult_len\t0\r\ntotal\t0\r\noffset\t0\r\nts\t1\r\n"];
    STAssertEquals([items count], (NSUInteger)0, @"no playlists");
}

#pragma mark - fio 10: monotonic-ts guard

- (void)testGuardAcceptsIncreasing
{
    DTSnapshotGuard *g = [[[DTSnapshotGuard alloc] init] autorelease];
    STAssertTrue([g acceptTs:100], @"first ts accepted");
    STAssertTrue([g acceptTs:200], @"increasing accepted");
    STAssertTrue([g acceptTs:200], @"equal ts (micro-cache) accepted");
}

- (void)testGuardRejectsRegression
{
    DTSnapshotGuard *g = [[[DTSnapshotGuard alloc] init] autorelease];
    STAssertTrue([g acceptTs:500], @"baseline");
    STAssertFalse([g acceptTs:499], @"a staler replica's ts is rejected");
    STAssertTrue([g acceptTs:500], @"the high-water mark is unchanged by a rejection");
    STAssertTrue([g acceptTs:600], @"forward again accepted");
}

- (void)testGuardZeroTsAlwaysAccepted
{
    DTSnapshotGuard *g = [[[DTSnapshotGuard alloc] init] autorelease];
    STAssertTrue([g acceptTs:1000], @"baseline");
    STAssertTrue([g acceptTs:0], @"unknown ts never blocks");
    STAssertFalse([g acceptTs:999], @"and did not move the mark");
}

- (void)testGuardReset
{
    DTSnapshotGuard *g = [[[DTSnapshotGuard alloc] init] autorelease];
    STAssertTrue([g acceptTs:1000], @"baseline");
    [g reset];
    STAssertTrue([g acceptTs:1], @"after reset, any ts is a fresh baseline");
}

#pragma mark - fio 10: cover cache key

- (void)testCoverCacheFileName
{
    STAssertEqualObjects([DTCoverCache fileNameForAlbum:@"3AB" size:300], @"3AB-300.jpg",
                         @"<album_id>-<size>.jpg");
    STAssertEqualObjects([DTCoverCache fileNameForAlbum:@"3AB" size:64], @"3AB-64.jpg",
                         @"64 thumb key differs from the 300");
}

- (void)testCoverCacheDiskPath
{
    DTCoverCache *c = [[[DTCoverCache alloc] initWithDirectory:@"/tmp/detoca-covers"] autorelease];
    STAssertEqualObjects([c diskPathForAlbum:@"abc" size:640], @"/tmp/detoca-covers/abc-640.jpg",
                         @"disk path joins dir + key");
}

@end
