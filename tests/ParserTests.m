//
//  ParserTests.m
//  DeToca — OCUnit (SenTestingKit) tests for the pure-Foundation parser layer.
//
//  Covers gophermap parsing, the ANSI/SGR state machine (including the
//  fbterm case-38 hazard), the 256-color palette, and location/URL parsing.
//  No AppKit — runs under otest on the 10.6 target via `make test`.
//

#import <SenTestingKit/SenTestingKit.h>

#import "GopherItem.h"
#import "GopherMenuParser.h"
#import "GopherResource.h"
#import "ANSIPalette.h"
#import "ANSISpan.h"
#import "ANSIParser.h"

// Helper: concatenate the text of every span.
static NSString *ConcatSpans(NSArray *spans)
{
    NSMutableString *s = [NSMutableString string];
    NSUInteger i, n = [spans count];
    for (i = 0; i < n; i++) {
        [s appendString:[[spans objectAtIndex:i] text]];
    }
    return s;
}

@interface ParserTests : SenTestCase
@end

@implementation ParserTests

#pragma mark - 256-color palette

- (void)testPaletteBase16
{
    ANSIRGB black = [ANSIPalette rgbForIndex:0];
    STAssertTrue(black.r == 0 && black.g == 0 && black.b == 0, @"index 0 black");

    ANSIRGB white = [ANSIPalette rgbForIndex:15];
    STAssertTrue(white.r == 255 && white.g == 255 && white.b == 255, @"index 15 white");

    ANSIRGB brightRed = [ANSIPalette rgbForIndex:9];
    STAssertTrue(brightRed.r == 255 && brightRed.g == 0 && brightRed.b == 0, @"index 9 bright red");
}

- (void)testPaletteCube
{
    ANSIRGB origin = [ANSIPalette rgbForIndex:16];   // cube 0,0,0
    STAssertTrue(origin.r == 0 && origin.g == 0 && origin.b == 0, @"16 = black");

    ANSIRGB blue = [ANSIPalette rgbForIndex:21];      // 0,0,5
    STAssertTrue(blue.r == 0 && blue.g == 0 && blue.b == 255, @"21 = pure blue");

    ANSIRGB red = [ANSIPalette rgbForIndex:196];      // 5,0,0
    STAssertTrue(red.r == 255 && red.g == 0 && red.b == 0, @"196 = pure red");

    ANSIRGB last = [ANSIPalette rgbForIndex:231];     // 5,5,5
    STAssertTrue(last.r == 255 && last.g == 255 && last.b == 255, @"231 = white");
}

- (void)testPaletteGrayscale
{
    ANSIRGB g0 = [ANSIPalette rgbForIndex:232];
    STAssertTrue(g0.r == 8 && g0.g == 8 && g0.b == 8, @"232 = gray 8");

    ANSIRGB g23 = [ANSIPalette rgbForIndex:255];
    STAssertTrue(g23.r == 238 && g23.g == 238 && g23.b == 238, @"255 = gray 238");
}

- (void)testPaletteClamping
{
    ANSIRGB lo = [ANSIPalette rgbForIndex:-5];
    STAssertTrue(lo.r == 0, @"negative clamps to 0");
    ANSIRGB hi = [ANSIPalette rgbForIndex:9999];
    STAssertTrue(hi.r == 238, @"overflow clamps to 255-index");
}

#pragma mark - ANSI parser

- (void)testPlainText
{
    NSArray *spans = [ANSIParser spansFromString:@"hello world"];
    STAssertEqualObjects(ConcatSpans(spans), @"hello world", @"plain text unchanged");
}

- (void)testEscapesStrippedFromText
{
    NSArray *spans = [ANSIParser spansFromString:@"a\x1b[1mb\x1b[0mc"];
    STAssertEqualObjects(ConcatSpans(spans), @"abc", @"escapes removed");
}

- (void)testBoldToggling
{
    NSArray *spans = [ANSIParser spansFromString:@"a\x1b[1mb\x1b[0mc"];
    STAssertEquals((int)[spans count], 3, @"three spans");
    STAssertFalse([[spans objectAtIndex:0] bold], @"a not bold");
    STAssertTrue([[spans objectAtIndex:1] bold], @"b bold");
    STAssertFalse([[spans objectAtIndex:2] bold], @"c reset");
}

- (void)testBasicForeground
{
    NSArray *spans = [ANSIParser spansFromString:@"\x1b[31mred\x1b[39mdef"];
    STAssertEquals((int)[spans count], 2, @"two spans");
    ANSISpan *red = [spans objectAtIndex:0];
    STAssertTrue([red hasForeground], @"has fg");
    STAssertTrue([red foreground].r == 0x80 && [red foreground].g == 0, @"31 dark red");
    STAssertFalse([[spans objectAtIndex:1] hasForeground], @"39 clears fg");
}

- (void)testBrightForeground
{
    NSArray *spans = [ANSIParser spansFromString:@"\x1b[91mX"];
    ANSISpan *s = [spans objectAtIndex:0];
    STAssertTrue([s foreground].r == 255 && [s foreground].g == 0 && [s foreground].b == 0,
                 @"91 bright red");
}

- (void)test256ColorForeground
{
    NSArray *spans = [ANSIParser spansFromString:@"\x1b[38;5;196mR"];
    ANSISpan *s = [spans objectAtIndex:0];
    STAssertTrue([s hasForeground] && [s foreground].r == 255 && [s foreground].g == 0,
                 @"38;5;196 = red");
}

- (void)test256ColorBackground
{
    NSArray *spans = [ANSIParser spansFromString:@"\x1b[48;5;21mB"];
    ANSISpan *s = [spans objectAtIndex:0];
    STAssertTrue([s hasBackground] && [s background].b == 255, @"48;5;21 bg blue");
}

// The fbterm "case 38" bug: a parser that mishandles 38;5;N swallows the
// parameters that follow it. Here the trailing "1" (bold) must still apply.
- (void)testCase38DoesNotSwallowFollowingParams
{
    NSArray *spans = [ANSIParser spansFromString:@"\x1b[38;5;196;1mX"];
    ANSISpan *s = [spans objectAtIndex:0];
    STAssertTrue([s foreground].r == 255, @"fg still red");
    STAssertTrue([s bold], @"bold after 38;5;N still applied");
}

- (void)testCombinedForegroundAndBackground
{
    NSArray *spans = [ANSIParser spansFromString:@"\x1b[38;5;46;48;5;16mX"];
    ANSISpan *s = [spans objectAtIndex:0];
    STAssertTrue([s foreground].g == 255 && [s foreground].r == 0, @"fg green");
    STAssertTrue([s hasBackground] && [s background].r == 0 && [s background].g == 0, @"bg black");
}

- (void)testTruecolor
{
    NSArray *spans = [ANSIParser spansFromString:@"\x1b[38;2;10;20;30mX"];
    ANSISpan *s = [spans objectAtIndex:0];
    STAssertTrue([s foreground].r == 10 && [s foreground].g == 20 && [s foreground].b == 30,
                 @"24-bit fg");
}

- (void)testEmptySGRIsReset
{
    NSArray *spans = [ANSIParser spansFromString:@"\x1b[1mA\x1b[mB"];
    STAssertFalse([[spans objectAtIndex:1] bold], @"ESC[m resets");
}

- (void)testNonSGRCSIStripped
{
    NSArray *spans = [ANSIParser spansFromString:@"a\x1b[2Kb"];
    STAssertEqualObjects(ConcatSpans(spans), @"ab", @"cursor/erase CSI stripped");
}

- (void)testUnsupportedSGRIgnoredButTextKept
{
    NSArray *spans = [ANSIParser spansFromString:@"\x1b[4mUL"];
    STAssertEqualObjects(ConcatSpans(spans), @"UL", @"underline text kept");
}

- (void)testBraillePreserved
{
    NSString *braille = @"⠀⣿⡇";
    NSArray *spans = [ANSIParser spansFromString:braille];
    STAssertEqualObjects(ConcatSpans(spans), braille, @"braille block untouched");
}

- (void)testUnterminatedCSIStrippedToEnd
{
    NSArray *spans = [ANSIParser spansFromString:@"ok\x1b[38;5"];
    STAssertEqualObjects(ConcatSpans(spans), @"ok", @"dangling CSI dropped");
}

#pragma mark - Gophermap parsing

- (void)testMenuParsing
{
    NSString *menu = @"iWelcome\tfake\t(NULL)\t0\r\n"
                     @"1Software\t/soft\tgopher.example.com\t70\r\n"
                     @"0About\t/about.txt\tgopher.example.com\t70\r\n"
                     @"7Search\t/search\tgopher.example.com\t70\r\n"
                     @"hHomepage\tURL:http://example.com/\tgopher.example.com\t70\r\n"
                     @".\r\n"
                     @"1HIDDEN\t/x\thost\t70\r\n";
    NSArray *items = [GopherMenuParser parseMenu:menu];
    STAssertEquals((int)[items count], 5, @"5 items, terminator stops parse");

    GopherItem *info = [items objectAtIndex:0];
    STAssertEquals((int)[info kind], (int)GopherItemKindInfo, @"info kind");
    STAssertFalse([info isClickable], @"info not clickable");
    STAssertEqualObjects([info displayString], @"Welcome", @"info display");

    GopherItem *dir = [items objectAtIndex:1];
    STAssertEquals((int)[dir kind], (int)GopherItemKindMenu, @"menu kind");
    STAssertEqualObjects([dir selector], @"/soft", @"selector");
    STAssertEquals((int)[dir port], 70, @"port 70");

    GopherItem *html = [items objectAtIndex:4];
    STAssertEquals((int)[html kind], (int)GopherItemKindHTML, @"html kind");
    STAssertEqualObjects([html externalURLString], @"http://example.com/", @"URL: extracted");
    STAssertTrue([html isClickable], @"html with URL clickable");
}

- (void)testMenuBareLFEndings
{
    NSArray *items = [GopherMenuParser parseMenu:@"1A\t/a\th\t70\n1B\t/b\th\t70\n"];
    STAssertEquals((int)[items count], 2, @"bare LF handled");
}

- (void)testMalformedNoTabsTolerated
{
    NSArray *items = [GopherMenuParser parseMenu:@"iJust text with no tabs\n"];
    STAssertEquals((int)[items count], 1, @"one item");
    GopherItem *only = [items objectAtIndex:0];
    STAssertEqualObjects([only selector], @"", @"empty selector");
    STAssertEqualObjects([only displayString], @"Just text with no tabs", @"display");
}

- (void)testBadPortDefaults
{
    NSArray *items = [GopherMenuParser parseMenu:@"1X\t/s\thost\tabc\n"];
    STAssertEquals((int)[[items objectAtIndex:0] port], 70, @"non-numeric port -> 70");
}

- (void)testUnknownTypeDimmed
{
    NSArray *items = [GopherMenuParser parseMenu:@"zMystery\t/m\thost\t70\n"];
    GopherItem *it = [items objectAtIndex:0];
    STAssertEquals((int)[it kind], (int)GopherItemKindUnknown, @"unknown kind");
    STAssertFalse([it isClickable], @"unknown not clickable");
}

- (void)testErrorType
{
    NSArray *items = [GopherMenuParser parseMenu:@"3Something failed\t\terror.host\t1\n"];
    STAssertEquals((int)[[items objectAtIndex:0] kind], (int)GopherItemKindError, @"error kind");
}

#pragma mark - Location / URL parsing

- (void)testGopherURL
{
    GopherResource *r = [GopherResource resourceFromLocationString:
                         @"gopher://gopher.floodgap.com/1/world"];
    STAssertNotNil(r, @"parsed");
    STAssertEqualObjects([r host], @"gopher.floodgap.com", @"host");
    STAssertEquals((int)[r port], 70, @"default port");
    STAssertEquals((int)[r type], (int)'1', @"type 1");
    STAssertEqualObjects([r selector], @"/world", @"selector");
}

- (void)testHostPortTypeSelector
{
    GopherResource *r = [GopherResource resourceFromLocationString:
                         @"example.com:7070/0/foo/bar"];
    STAssertEqualObjects([r host], @"example.com", @"host");
    STAssertEquals((int)[r port], 7070, @"explicit port");
    STAssertEquals((int)[r type], (int)'0', @"type 0");
    STAssertEqualObjects([r selector], @"/foo/bar", @"selector keeps slashes");
}

- (void)testBareHostIsRootMenu
{
    GopherResource *r = [GopherResource resourceFromLocationString:@"gopher.debene.dev"];
    STAssertEquals((int)[r type], (int)'1', @"root type");
    STAssertEqualObjects([r selector], @"", @"empty selector");
}

- (void)testBlankLocationRejected
{
    STAssertNil([GopherResource resourceFromLocationString:@"   "], @"blank -> nil");
    STAssertNil([GopherResource resourceFromLocationString:nil], @"nil -> nil");
}

- (void)testRoundTripThroughItem
{
    GopherItem *item = [GopherItem itemWithType:'0'
                                        display:@"About"
                                       selector:@"/about"
                                           host:@"h.example"
                                           port:71];
    GopherResource *r = [GopherResource resourceWithItem:item];
    STAssertEqualObjects([r locationSummary], @"h.example:71/about", @"summary");
}

@end
