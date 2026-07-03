//
//  GopherMenuView.m
//  DeToca — fio 6
//

#import "GopherMenuView.h"
#import "GopherItem.h"
#import "GopherTableView.h"
#import "DTFontManager.h"

@interface GopherMenuView ()
- (void)openSelected:(id)sender;
@end

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

@implementation GopherMenuView

@synthesize menuDelegate = _menuDelegate;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self == nil) {
        return nil;
    }

    _scrollView = [[NSScrollView alloc] initWithFrame:[self bounds]];
    [_scrollView setBorderType:NSBezelBorder];
    [_scrollView setHasVerticalScroller:YES];
    [_scrollView setHasHorizontalScroller:NO];
    [_scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [_scrollView setDrawsBackground:YES];
    [_scrollView setBackgroundColor:[NSColor blackColor]];

    NSSize cs = [_scrollView contentSize];
    _tableView = [[GopherTableView alloc]
                  initWithFrame:NSMakeRect(0, 0, cs.width, cs.height)];

    NSTableColumn *col = [[[NSTableColumn alloc] initWithIdentifier:@"item"] autorelease];
    [col setWidth:cs.width];
    [col setEditable:NO];
    [_tableView addTableColumn:col];
    [_tableView setHeaderView:nil];

    // Row height tracks the monospace font's line height, plus a few pixels so
    // NSTextFieldCell doesn't clip descenders. Intercell spacing is zero so
    // ASCII-art info lines (boxes, rules) connect vertically.
    NSFont *menuFont = [DTFontManager documentFont];
    NSLayoutManager *lm = [[NSLayoutManager alloc] init];
    CGFloat lineH = [lm defaultLineHeightForFont:menuFont];
    [lm release];
    [_tableView setRowHeight:ceil(lineH) + 3.0];
    [_tableView setIntercellSpacing:NSMakeSize(0.0, 0.0)];
    [_tableView setBackgroundColor:[NSColor blackColor]];
    [_tableView setUsesAlternatingRowBackgroundColors:NO];
    [_tableView setGridStyleMask:NSTableViewGridNone];
    [_tableView setColumnAutoresizingStyle:NSTableViewLastColumnOnlyAutoresizingStyle];
    [_tableView setAllowsMultipleSelection:NO];
    [_tableView setDataSource:self];
    [_tableView setDelegate:self];
    [_tableView setTarget:self];
    [_tableView setDoubleAction:@selector(openSelected:)];

    [_scrollView setDocumentView:_tableView];
    [self addSubview:_scrollView];
    return self;
}

- (void)dealloc
{
    [_items release];
    [_tableView release];
    [_scrollView release];
    [super dealloc];
}

- (GopherTableView *)tableView
{
    return _tableView;
}

- (NSArray *)items
{
    return _items;
}

- (void)setItems:(NSArray *)items
{
    NSArray *copy = [items copy];
    [_items release];
    _items = copy;
    [_tableView reloadData];
    // Reset scroll + selection to the top for a fresh menu.
    if ([_items count] > 0) {
        [_tableView scrollRowToVisible:0];
    }
}

- (void)openSelected:(id)sender
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
    if (_menuDelegate != nil) {
        [_menuDelegate gopherMenuView:self didActivateItem:item];
    }
}

#pragma mark - NSTableView data source / delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return (NSInteger)[_items count];
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

    NSMutableAttributedString *lineStr =
        [[[NSMutableAttributedString alloc] init] autorelease];

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

    [lineStr appendAttributedString:tagStr];
    [lineStr appendAttributedString:dispStr];
    return lineStr;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    if (row < 0 || row >= (NSInteger)[_items count]) {
        return NO;
    }
    return [[_items objectAtIndex:row] isClickable];
}

@end
