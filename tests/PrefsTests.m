//
//  PrefsTests.m
//  DeToca — OCUnit tests for the fio-8 pure model layer:
//  DTServerPrefs (host/port validation + defaults-backed persistence) and
//  DTMediaKeyRouter (media-key decode + action policy). Pure Foundation.
//

#import <SenTestingKit/SenTestingKit.h>

#import "DTServerPrefs.h"
#import "DTMediaKeyRouter.h"

@interface PrefsTests : SenTestCase {
    id _savedHost;
    id _savedPort;
}
@end

@implementation PrefsTests

// Preserve any real DTSpotHost/DTSpotPort so the suite is hermetic.
- (void)setUp
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    _savedHost = [[d objectForKey:DTSpotHostKey] retain];
    _savedPort = [[d objectForKey:DTSpotPortKey] retain];
    [d removeObjectForKey:DTSpotHostKey];
    [d removeObjectForKey:DTSpotPortKey];
}

- (void)tearDown
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (_savedHost) { [d setObject:_savedHost forKey:DTSpotHostKey]; }
    else            { [d removeObjectForKey:DTSpotHostKey]; }
    if (_savedPort) { [d setObject:_savedPort forKey:DTSpotPortKey]; }
    else            { [d removeObjectForKey:DTSpotPortKey]; }
    [d synchronize];
    [_savedHost release]; _savedHost = nil;
    [_savedPort release]; _savedPort = nil;
}

#pragma mark - DTServerPrefs validation

- (void)testHostValidation
{
    STAssertFalse([DTServerPrefs isValidHost:nil], @"nil host invalid");
    STAssertFalse([DTServerPrefs isValidHost:@""], @"empty host invalid");
    STAssertFalse([DTServerPrefs isValidHost:@"   "], @"whitespace host invalid");
    STAssertTrue([DTServerPrefs isValidHost:@"gopher.debene.dev"], @"host valid");
    STAssertTrue([DTServerPrefs isValidHost:@"  10.0.100.112  "], @"trimmed host valid");
}

- (void)testPortValidation
{
    STAssertFalse([DTServerPrefs isValidPort:0], @"0 invalid");
    STAssertFalse([DTServerPrefs isValidPort:-1], @"negative invalid");
    STAssertFalse([DTServerPrefs isValidPort:65536], @"65536 invalid");
    STAssertFalse([DTServerPrefs isValidPort:100000], @"out of range invalid");
    STAssertTrue([DTServerPrefs isValidPort:1], @"1 valid");
    STAssertTrue([DTServerPrefs isValidPort:70], @"70 valid");
    STAssertTrue([DTServerPrefs isValidPort:65535], @"65535 valid");
}

- (void)testCombinedValidation
{
    STAssertTrue([DTServerPrefs isValidHost:@"h" port:70], @"both valid");
    STAssertFalse([DTServerPrefs isValidHost:@"" port:70], @"bad host");
    STAssertFalse([DTServerPrefs isValidHost:@"h" port:0], @"bad port");
}

#pragma mark - DTServerPrefs defaults + persistence

- (void)testDefaultsWhenUnset
{
    STAssertEqualObjects([DTServerPrefs host], [DTServerPrefs defaultHost],
                         @"unset host falls back to default");
    STAssertEquals([DTServerPrefs port], [DTServerPrefs defaultPort],
                   @"unset port falls back to default");
    STAssertEquals([DTServerPrefs defaultPort], (NSInteger)70, @"default port is 70");
}

- (void)testSaveChangesAndReports
{
    BOOL changed = [DTServerPrefs saveHost:@"example.com" port:71];
    STAssertTrue(changed, @"first save from defaults is a change");
    STAssertEqualObjects([DTServerPrefs host], @"example.com", @"host persisted");
    STAssertEquals([DTServerPrefs port], (NSInteger)71, @"port persisted");
}

- (void)testSaveNoChangeReturnsNo
{
    [DTServerPrefs saveHost:@"example.com" port:71];
    BOOL changed = [DTServerPrefs saveHost:@"example.com" port:71];
    STAssertFalse(changed, @"saving identical values reports no change");
}

- (void)testSaveTrimsHost
{
    [DTServerPrefs saveHost:@"  spot.local  " port:70];
    STAssertEqualObjects([DTServerPrefs host], @"spot.local", @"host trimmed on save");
}

- (void)testSaveRejectsInvalid
{
    [DTServerPrefs saveHost:@"good.host" port:70];
    BOOL changed = [DTServerPrefs saveHost:@"" port:70];
    STAssertFalse(changed, @"invalid save reports no change");
    STAssertEqualObjects([DTServerPrefs host], @"good.host", @"invalid save does not overwrite");

    changed = [DTServerPrefs saveHost:@"good.host" port:99999];
    STAssertFalse(changed, @"invalid port save reports no change");
    STAssertEquals([DTServerPrefs port], (NSInteger)70, @"invalid port save does not overwrite");
}

#pragma mark - DTMediaKeyRouter decode

- (void)testKeyCodeDecode
{
    STAssertEquals([DTMediaKeyRouter kindForKeyCode:DTNXKeyTypePlay],
                   DTMediaKeyPlayPause, @"16 -> play/pause");
    STAssertEquals([DTMediaKeyRouter kindForKeyCode:DTNXKeyTypeNext],
                   DTMediaKeyNext, @"19 -> next");
    STAssertEquals([DTMediaKeyRouter kindForKeyCode:DTNXKeyTypePrev],
                   DTMediaKeyPrevious, @"20 -> previous");
    STAssertEquals([DTMediaKeyRouter kindForKeyCode:7],
                   DTMediaKeyNone, @"volume/other -> none");
}

#pragma mark - DTMediaKeyRouter policy

- (void)testPlayWhenConnectedToggles
{
    STAssertEquals([DTMediaKeyRouter actionForKind:DTMediaKeyPlayPause
                        pressed:YES isRepeat:NO connected:YES],
                   DTMediaKeyActionTogglePlayPause, @"play toggles when live");
}

- (void)testPlayWhenDisconnectedReconnects
{
    STAssertEquals([DTMediaKeyRouter actionForKind:DTMediaKeyPlayPause
                        pressed:YES isRepeat:NO connected:NO],
                   DTMediaKeyActionReconnectAndPlay, @"play revives radinho when idle");
}

- (void)testRepeatIgnoredForPlay
{
    STAssertEquals([DTMediaKeyRouter actionForKind:DTMediaKeyPlayPause
                        pressed:YES isRepeat:YES connected:YES],
                   DTMediaKeyActionNone, @"held play does not double-toggle");
}

- (void)testKeyUpIgnored
{
    STAssertEquals([DTMediaKeyRouter actionForKind:DTMediaKeyPlayPause
                        pressed:NO isRepeat:NO connected:YES],
                   DTMediaKeyActionNone, @"key-up is ignored");
    STAssertEquals([DTMediaKeyRouter actionForKind:DTMediaKeyNext
                        pressed:NO isRepeat:NO connected:YES],
                   DTMediaKeyActionNone, @"next key-up ignored");
}

- (void)testNextPrevWhenConnected
{
    STAssertEquals([DTMediaKeyRouter actionForKind:DTMediaKeyNext
                        pressed:YES isRepeat:NO connected:YES],
                   DTMediaKeyActionNext, @"next when live");
    STAssertEquals([DTMediaKeyRouter actionForKind:DTMediaKeyPrevious
                        pressed:YES isRepeat:NO connected:YES],
                   DTMediaKeyActionPrevious, @"prev when live");
}

- (void)testNextPrevWhenDisconnectedAreNoOp
{
    STAssertEquals([DTMediaKeyRouter actionForKind:DTMediaKeyNext
                        pressed:YES isRepeat:NO connected:NO],
                   DTMediaKeyActionNone, @"next is a silent no-op when idle");
    STAssertEquals([DTMediaKeyRouter actionForKind:DTMediaKeyPrevious
                        pressed:YES isRepeat:NO connected:NO],
                   DTMediaKeyActionNone, @"prev is a silent no-op when idle");
}

- (void)testNoneKindIsNoOp
{
    STAssertEquals([DTMediaKeyRouter actionForKind:DTMediaKeyNone
                        pressed:YES isRepeat:NO connected:YES],
                   DTMediaKeyActionNone, @"unhandled key -> no action");
}

@end
