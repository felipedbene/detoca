//
//  PlayerTests.m
//  DeToca — OCUnit tests for the fio-2 model layer (StreamRouting, PlayQueue).
//  Pure Foundation; no AppKit or QTKit.
//

#import <SenTestingKit/SenTestingKit.h>

#import "StreamRouting.h"
#import "PlayQueue.h"
#import "PlayQueueItem.h"

@interface PlayerTests : SenTestCase
@end

@implementation PlayerTests

#pragma mark - StreamRouting

- (void)testPlainMP3
{
    STAssertTrue([StreamRouting isPlayableStreamURLString:@"http://spot.debene.dev/x/track.mp3"],
                 @"http .mp3 is playable");
    STAssertTrue([StreamRouting isPlayableStreamURLString:@"https://host/a/b/song.mp3"],
                 @"https .mp3 is playable");
}

- (void)testMP3WithQueryString
{
    STAssertTrue([StreamRouting isPlayableStreamURLString:
                  @"http://host/track.mp3?token=abc123&x=1"], @"query stripped");
    STAssertTrue([StreamRouting isPlayableStreamURLString:
                  @"http://host/track.mp3#t=30"], @"fragment stripped");
}

- (void)testUppercaseExtension
{
    STAssertTrue([StreamRouting isPlayableStreamURLString:@"http://host/TRACK.MP3"],
                 @"uppercase extension");
    STAssertTrue([StreamRouting isPlayableStreamURLString:@"HTTP://HOST/Track.Mp3"],
                 @"uppercase scheme + mixed extension");
}

- (void)testNonMP3StaysExternal
{
    STAssertFalse([StreamRouting isPlayableStreamURLString:@"http://host/page.html"],
                  @"html not playable");
    STAssertFalse([StreamRouting isPlayableStreamURLString:@"http://host/track.ogg"],
                  @"ogg not playable");
    STAssertFalse([StreamRouting isPlayableStreamURLString:@"http://host/mp3-info"],
                  @"substring mp3 without extension not playable");
}

- (void)testNonHTTPSchemeStaysExternal
{
    STAssertFalse([StreamRouting isPlayableStreamURLString:@"gopher://host/9/track.mp3"],
                  @"gopher scheme not playable");
    STAssertFalse([StreamRouting isPlayableStreamURLString:@"ftp://host/track.mp3"],
                  @"ftp not playable");
    STAssertFalse([StreamRouting isPlayableStreamURLString:@"file:///Users/x/track.mp3"],
                  @"file not playable");
    STAssertFalse([StreamRouting isPlayableStreamURLString:nil], @"nil not playable");
}

#pragma mark - PlayQueue

static NSArray *ThreeItems(void)
{
    return [NSArray arrayWithObjects:
            [PlayQueueItem itemWithTitle:@"One"   urlString:@"http://h/1.mp3"],
            [PlayQueueItem itemWithTitle:@"Two"   urlString:@"http://h/2.mp3"],
            [PlayQueueItem itemWithTitle:@"Three" urlString:@"http://h/3.mp3"],
            nil];
}

- (void)testBuildAtIndex
{
    PlayQueue *q = [[[PlayQueue alloc] initWithItems:ThreeItems() startIndex:1] autorelease];
    STAssertEquals((int)[q count], 3, @"three items");
    STAssertEquals((int)[q currentIndex], 1, @"starts at index 1");
    STAssertEqualObjects([[q currentItem] title], @"Two", @"current is Two");
    STAssertEqualObjects([q positionString], @"2 / 3", @"position 2 / 3");
}

- (void)testBuildAtIndexClamps
{
    PlayQueue *q = [[[PlayQueue alloc] initWithItems:ThreeItems() startIndex:99] autorelease];
    STAssertEquals((int)[q currentIndex], 2, @"clamped to last");
    PlayQueue *q2 = [[[PlayQueue alloc] initWithItems:ThreeItems() startIndex:-5] autorelease];
    STAssertEquals((int)[q2 currentIndex], 0, @"clamped to first");
}

- (void)testAdvancePastEnd
{
    PlayQueue *q = [[[PlayQueue alloc] initWithItems:ThreeItems() startIndex:0] autorelease];
    STAssertEqualObjects([[q advanceToNext] title], @"Two", @"advance to Two");
    STAssertEqualObjects([[q advanceToNext] title], @"Three", @"advance to Three");
    STAssertTrue([q hasNext] == NO, @"no next at end");
    STAssertNil([q advanceToNext], @"advance past end returns nil");
    STAssertEquals((int)[q currentIndex], 2, @"index parks on last");
    STAssertEqualObjects([[q currentItem] title], @"Three", @"still showing Three");
}

- (void)testPrevAtStart
{
    PlayQueue *q = [[[PlayQueue alloc] initWithItems:ThreeItems() startIndex:0] autorelease];
    STAssertTrue([q hasPrevious] == NO, @"no previous at start");
    STAssertNil([q goToPrevious], @"previous at start returns nil");
    STAssertEquals((int)[q currentIndex], 0, @"index unchanged");
}

- (void)testPrevAfterAdvance
{
    PlayQueue *q = [[[PlayQueue alloc] initWithItems:ThreeItems() startIndex:0] autorelease];
    [q advanceToNext];
    STAssertEqualObjects([[q goToPrevious] title], @"One", @"back to One");
}

- (void)testReplaceMidPlayback
{
    PlayQueue *q = [[[PlayQueue alloc] initWithItems:ThreeItems() startIndex:2] autorelease];
    STAssertEqualObjects([[q currentItem] title], @"Three", @"was on Three");

    NSArray *other = [NSArray arrayWithObjects:
            [PlayQueueItem itemWithTitle:@"A" urlString:@"http://h/a.mp3"],
            [PlayQueueItem itemWithTitle:@"B" urlString:@"http://h/b.mp3"], nil];
    [q replaceWithItems:other startIndex:0];
    STAssertEquals((int)[q count], 2, @"replaced with two");
    STAssertEquals((int)[q currentIndex], 0, @"reset to 0");
    STAssertEqualObjects([[q currentItem] title], @"A", @"now on A");
    STAssertEqualObjects([q positionString], @"1 / 2", @"position 1 / 2");
}

- (void)testEmptyQueue
{
    PlayQueue *q = [[[PlayQueue alloc] initWithItems:[NSArray array] startIndex:0] autorelease];
    STAssertEquals((int)[q count], 0, @"empty");
    STAssertEquals((int)[q currentIndex], -1, @"index -1 when empty");
    STAssertNil([q currentItem], @"no current item");
    STAssertEqualObjects([q positionString], @"", @"empty position string");
}

@end
