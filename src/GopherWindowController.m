//
//  GopherWindowController.m
//  DeToca
//

#import "GopherWindowController.h"
#import "GopherResource.h"
#import "GopherItem.h"
#import "GopherMenuParser.h"
#import "GopherTableView.h"
#import "AttributedStringRenderer.h"
#import "DTFontManager.h"
#import "StreamRouting.h"
#import "AppDelegate.h"

#define DT_STATUS_HEIGHT 22.0
#define DT_WINDOW_W 640.0
#define DT_WINDOW_H 480.0

// Private helpers (declared up front so GCC 4.2 sees them before use).
@interface GopherWindowController ()
- (void)positionRelativeToParent:(NSWindow *)parent;
- (void)buildChrome;
- (NSScrollView *)makeScrollViewFilling:(NSRect)rect;
- (void)buildMenuView;
- (void)buildTextViewWithAttributedString:(NSAttributedString *)attr;
- (void)openSelectedItem:(id)sender;
@end

@implementation GopherWindowController

@synthesize resource = _resource;

- (id)initWithResource:(GopherResource *)resource parentWindow:(NSWindow *)parent
{
    NSRect frame = NSMakeRect(0, 0, DT_WINDOW_W, DT_WINDOW_H);
    NSUInteger style = (NSTitledWindowMask | NSClosableWindowMask |
                        NSMiniaturizableWindowMask | NSResizableWindowMask);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:YES];
    [window setReleasedWhenClosed:NO];
    [window setMinSize:NSMakeSize(320, 240)];

    self = [super initWithWindow:window];
    [window release];
    if (self == nil) {
        return nil;
    }

    _resource = [resource retain];
    _menuMode = ([resource type] != '0');

    NSString *title = [resource displayString];
    if ([title length] == 0) {
        title = [resource host];
    }
    [window setTitle:(title ? title : @"DeToca")];
    [window setDelegate:self];

    [self positionRelativeToParent:parent];
    [self buildChrome];

    return self;
}

- (void)dealloc
{
    [_request cancel];
    [_request release];
    [_resource release];
    [_items release];
    [_localText release];
    [super dealloc];
}

#pragma mark - Window placement

- (void)positionRelativeToParent:(NSWindow *)parent
{
    NSWindow *window = [self window];
    if (parent != nil) {
        NSRect p = [parent frame];
        // Cascade down-right from the parent's top-left (TurboGopher style).
        NSPoint topLeft = NSMakePoint(NSMinX(p) + 22.0, NSMaxY(p) - 22.0);
        [window setFrameTopLeftPoint:topLeft];
        // Keep the new window on screen.
        NSRect vis = [[window screen] visibleFrame];
        if (vis.size.width > 0) {
            NSRect f = [window frame];
            if (NSMaxX(f) > NSMaxX(vis) || NSMinY(f) < NSMinY(vis)) {
                [window center];
            }
        }
    } else {
        [window center];
    }
}

#pragma mark - View construction

- (void)buildChrome
{
    NSView *content = [[self window] contentView];
    NSRect b = [content bounds];

    // Status bar at the bottom shows host:port/selector.
    _statusLabel = [[[NSTextField alloc]
        initWithFrame:NSMakeRect(6, 3, b.size.width - 12, DT_STATUS_HEIGHT - 5)] autorelease];
    [_statusLabel setBezeled:NO];
    [_statusLabel setBordered:NO];
    [_statusLabel setEditable:NO];
    [_statusLabel setSelectable:YES];
    [_statusLabel setDrawsBackground:NO];
    [_statusLabel setFont:[NSFont systemFontOfSize:10.0]];
    [_statusLabel setTextColor:[NSColor darkGrayColor]];
    [_statusLabel setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [_statusLabel setStringValue:[_resource locationSummary]];
    [content addSubview:_statusLabel];

    // Body area above the status bar.
    NSRect bodyRect = NSMakeRect(0, DT_STATUS_HEIGHT,
                                 b.size.width, b.size.height - DT_STATUS_HEIGHT);
    _bodyArea = [[[NSView alloc] initWithFrame:bodyRect] autorelease];
    [_bodyArea setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [content addSubview:_bodyArea];

    // Spinner centered in the body area.
    _spinner = [[[NSProgressIndicator alloc]
        initWithFrame:NSMakeRect((bodyRect.size.width - 32) / 2,
                                 (bodyRect.size.height - 32) / 2, 32, 32)] autorelease];
    [_spinner setStyle:NSProgressIndicatorSpinningStyle];
    [_spinner setDisplayedWhenStopped:NO];
    [_spinner setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin |
                                   NSViewMinYMargin | NSViewMaxYMargin)];
    [_bodyArea addSubview:_spinner];
}

- (NSScrollView *)makeScrollViewFilling:(NSRect)rect
{
    NSScrollView *sv = [[[NSScrollView alloc] initWithFrame:rect] autorelease];
    [sv setBorderType:NSBezelBorder];
    [sv setHasVerticalScroller:YES];
    [sv setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    // Dark terminal theme throughout: keep the area beyond the content dark
    // for both menus and documents.
    [sv setDrawsBackground:YES];
    [sv setBackgroundColor:[NSColor blackColor]];
    return sv;
}

- (void)buildMenuView
{
    NSRect rect = [_bodyArea bounds];
    NSScrollView *sv = [self makeScrollViewFilling:rect];
    [sv setHasHorizontalScroller:NO];

    NSSize cs = [sv contentSize];
    GopherTableView *table = [[[GopherTableView alloc]
        initWithFrame:NSMakeRect(0, 0, cs.width, cs.height)] autorelease];

    NSTableColumn *col = [[[NSTableColumn alloc] initWithIdentifier:@"item"] autorelease];
    [col setWidth:cs.width];
    [col setEditable:NO];
    [table addTableColumn:col];
    [table setHeaderView:nil];
    // Row height tracks the monospace font's line height, plus a few pixels so
    // NSTextFieldCell doesn't clip descenders (the "low on ink" look). Intercell
    // spacing is zero so ASCII-art info lines (boxes, rules) still connect
    // vertically with only that small in-cell padding between them.
    NSFont *menuFont = [DTFontManager documentFont];
    NSLayoutManager *lm = [[NSLayoutManager alloc] init];
    CGFloat lineH = [lm defaultLineHeightForFont:menuFont];
    [lm release];
    [table setRowHeight:ceil(lineH) + 3.0];
    [table setIntercellSpacing:NSMakeSize(0.0, 0.0)];
    // Dark terminal theme: menus match text documents.
    [table setBackgroundColor:[NSColor blackColor]];
    [table setUsesAlternatingRowBackgroundColors:NO];
    [table setGridStyleMask:NSTableViewGridNone];
    [table setColumnAutoresizingStyle:NSTableViewLastColumnOnlyAutoresizingStyle];
    [table setAllowsMultipleSelection:NO];
    [table setDataSource:self];
    [table setDelegate:self];
    [table setTarget:self];
    [table setDoubleAction:@selector(openSelectedItem:)];

    [sv setDocumentView:table];
    [_bodyArea addSubview:sv];
    _tableView = table;
    [[self window] makeFirstResponder:table];
}

- (void)buildTextViewWithAttributedString:(NSAttributedString *)attr
{
    NSRect rect = [_bodyArea bounds];
    NSScrollView *sv = [self makeScrollViewFilling:rect];
    [sv setHasHorizontalScroller:YES];   // preformatted content: scroll, no wrap
    [sv setAutohidesScrollers:NO];

    NSSize cs = [sv contentSize];

    NSTextView *tv = [[[NSTextView alloc]
        initWithFrame:NSMakeRect(0, 0, cs.width, cs.height)] autorelease];
    // Install into the scroll view FIRST, then configure for no-wrap: adopting
    // a text view as a document view resets widthTracksTextView, so the no-wrap
    // container setup must come afterwards or preformatted lines wrap per char.
    [sv setDocumentView:tv];

    [tv setMinSize:NSMakeSize(cs.width, cs.height)];
    [tv setMaxSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
    [tv setVerticallyResizable:YES];
    [tv setHorizontallyResizable:YES];
    [tv setAutoresizingMask:NSViewNotSizable];
    [[tv textContainer] setContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
    [[tv textContainer] setWidthTracksTextView:NO];

    [tv setEditable:NO];
    [tv setSelectable:YES];
    [tv setRichText:YES];
    [tv setDrawsBackground:YES];
    // Terminal-style dark background: the gopher-cta maps' colors (rivers,
    // expressways) are authored for a dark terminal and are unreadable on white.
    [tv setBackgroundColor:[NSColor blackColor]];
    [tv setTextColor:[NSColor colorWithDeviceWhite:0.90 alpha:1.0]];
    [tv setInsertionPointColor:[NSColor whiteColor]];

    if (attr != nil) {
        [[tv textStorage] setAttributedString:attr];
    }
    [tv scrollRangeToVisible:NSMakeRange(0, 0)];

    [_bodyArea addSubview:sv];
    _textView = tv;
    [[self window] makeFirstResponder:tv];
}

#pragma mark - Loading

- (void)startFetch
{
    if (_localText != nil) {
        return;  // local content already rendered
    }
    [_spinner startAnimation:self];

    _request = [[GopherRequest requestWithHost:[_resource host]
                                          port:[_resource port]
                                      selector:[_resource selector]] retain];
    [_request setDelegate:self];
    [_request start];
}

- (void)loadLocalMenuText:(NSString *)text
{
    [_localText release];
    _localText = [text copy];
    _menuMode = YES;

    [_items release];
    _items = [[GopherMenuParser parseMenu:text] retain];

    [_statusLabel setStringValue:@"Bookmarks (local gophermap)"];
    [self buildMenuView];
    [_tableView reloadData];
}

#pragma mark - GopherRequestDelegate (main thread)

- (void)gopherRequest:(GopherRequest *)request didReceiveData:(NSData *)data
{
    [_spinner stopAnimation:self];

    if (_menuMode) {
        [_items release];
        _items = [[GopherMenuParser parseMenuData:data] retain];
        [self buildMenuView];
        [_tableView reloadData];
    } else {
        NSFont *font = [DTFontManager documentFont];
        NSAttributedString *attr =
            [AttributedStringRenderer attributedStringFromData:data font:font];
        [self buildTextViewWithAttributedString:attr];
    }
}

- (void)gopherRequest:(GopherRequest *)request didFailWithError:(NSError *)error
{
    [_spinner stopAnimation:self];

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:@"Could not open this Gopher item."];
    [alert setInformativeText:[error localizedDescription]];
    [alert addButtonWithTitle:@"OK"];
    [alert beginSheetModalForWindow:[self window]
                      modalDelegate:nil
                     didEndSelector:NULL
                        contextInfo:NULL];
}

#pragma mark - Activation

- (void)openSelectedItem:(id)sender
{
    NSInteger row = [_tableView clickedRow];
    if (row < 0) {
        row = [_tableView selectedRow];
    }
    if (row < 0 || row >= (NSInteger)[_items count]) {
        return;
    }
    GopherItem *item = [_items objectAtIndex:row];
    if (![item isClickable]) {
        return;
    }
    AppDelegate *app = (AppDelegate *)[NSApp delegate];
    [app openItem:item fromWindow:[self window]];
}

- (NSArray *)playableStreamItems
{
    NSMutableArray *streams = [NSMutableArray array];
    NSUInteger i, n = [_items count];
    for (i = 0; i < n; i++) {
        GopherItem *item = [_items objectAtIndex:i];
        if ([item kind] == GopherItemKindHTML &&
            [StreamRouting isPlayableStreamURLString:[item externalURLString]]) {
            [streams addObject:item];
        }
    }
    return streams;
}

#pragma mark - NSTableView data source / delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return (NSInteger)[_items count];
}

// A fixed-width bracketed tag per item type (period-correct, no emoji).
static NSString *TagForKind(GopherItemKind kind)
{
    switch (kind) {
        case GopherItemKindMenu:    return @"[DIR]";
        case GopherItemKindText:    return @"[TXT]";
        case GopherItemKindSearch:  return @"[FND]";
        case GopherItemKindHTML:    return @"[WWW]";
        case GopherItemKindSound:   return @"[SND]";
        case GopherItemKindError:   return @"[ERR]";
        case GopherItemKindInfo:    return @"     ";
        case GopherItemKindUnknown:
        default:                    return @"[ ? ]";
    }
}

- (id)tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)column
                          row:(NSInteger)row
{
    if (row < 0 || row >= (NSInteger)[_items count]) {
        return @"";
    }
    GopherItem *item = [_items objectAtIndex:row];
    GopherItemKind kind = [item kind];

    NSString *tag = TagForKind(kind);
    NSString *display = [item displayString];
    if (display == nil) {
        display = @"";
    }

    // Row color by kind, tuned for the dark terminal background.
    NSColor *textColor;
    switch (kind) {
        case GopherItemKindInfo:
            textColor = [NSColor colorWithDeviceWhite:0.62 alpha:1.0]; break;
        case GopherItemKindUnknown:
            textColor = [NSColor colorWithDeviceWhite:0.45 alpha:1.0]; break;
        case GopherItemKindError:
            textColor = [NSColor colorWithDeviceRed:1.0 green:0.45 blue:0.45 alpha:1.0]; break;
        default:
            textColor = [NSColor colorWithDeviceWhite:0.90 alpha:1.0]; break;
    }

    NSMutableAttributedString *line =
        [[[NSMutableAttributedString alloc] init] autorelease];

    // Render menus in the monospaced document font: gopher menus routinely put
    // ASCII art and aligned columns in info lines (e.g. the askthedeck dcgi
    // draws boxed tarot cards), which only line up in a fixed-pitch font. The
    // uniform-width type tag then keeps every row on one monospace grid.
    NSFont *menuFont = [DTFontManager documentFont];

    NSDictionary *tagAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
        menuFont, NSFontAttributeName,
        [NSColor colorWithDeviceWhite:0.55 alpha:1.0], NSForegroundColorAttributeName, nil];
    NSAttributedString *tagStr =
        [[[NSAttributedString alloc] initWithString:[tag stringByAppendingString:@"  "]
                                         attributes:tagAttrs] autorelease];

    NSDictionary *dispAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
        menuFont, NSFontAttributeName,
        textColor, NSForegroundColorAttributeName, nil];
    NSAttributedString *dispStr =
        [[[NSAttributedString alloc] initWithString:display
                                         attributes:dispAttrs] autorelease];

    [line appendAttributedString:tagStr];
    [line appendAttributedString:dispStr];
    return line;
}

// Only allow selecting clickable rows (info/error/unknown are inert).
- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    if (row < 0 || row >= (NSInteger)[_items count]) {
        return NO;
    }
    return [[_items objectAtIndex:row] isClickable];
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification
{
    [_request cancel];
    AppDelegate *app = (AppDelegate *)[NSApp delegate];
    [app gopherWindowWillClose:self];
}

@end
