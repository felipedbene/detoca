//
//  SpotAPITests.m
//  DeToca — OCUnit tests for the fio-9 machine-API model layer (DTNowSnapshot).
//  Pure Foundation; the networked DTSpotAPI is not exercised here.
//

#import <SenTestingKit/SenTestingKit.h>

#import "DTNowSnapshot.h"

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

@end
