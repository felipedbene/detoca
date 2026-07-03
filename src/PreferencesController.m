//
//  PreferencesController.m
//  DeToca
//

#import "PreferencesController.h"
#import "DTFontManager.h"

@interface PreferencesController ()
- (void)refresh;
- (void)chooseFont:(id)sender;
@end

@implementation PreferencesController

// Helper: a non-editable, borderless label.
static NSTextField *MakeLabel(NSRect frame, NSString *text, BOOL bold)
{
    NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [label setStringValue:(text ? text : @"")];
    [label setBezeled:NO];
    [label setBordered:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setDrawsBackground:NO];
    if (bold) {
        [label setFont:[NSFont boldSystemFontOfSize:13.0]];
    }
    return label;
}

- (id)init
{
    NSRect frame = NSMakeRect(0, 0, 480, 180);
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask)
                    backing:NSBackingStoreBuffered
                      defer:YES];
    [window setTitle:@"Preferences"];
    [window setReleasedWhenClosed:NO];

    self = [super initWithWindow:window];
    [window release];
    if (self == nil) {
        return nil;
    }

    NSView *content = [window contentView];

    NSTextField *heading = MakeLabel(NSMakeRect(20, 140, 440, 20),
        @"Document Font", YES);
    [content addSubview:heading];

    NSTextField *sub = MakeLabel(NSMakeRect(20, 118, 440, 18),
        @"Used to render text documents and ANSI/braille maps.", NO);
    [sub setFont:[NSFont systemFontOfSize:11.0]];
    [sub setTextColor:[NSColor darkGrayColor]];
    [content addSubview:sub];

    _fontField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 82, 350, 24)];
    [_fontField setEditable:NO];
    [_fontField setSelectable:YES];
    [_fontField setBezeled:YES];
    [_fontField setBezelStyle:NSTextFieldRoundedBezel];
    [content addSubview:_fontField];

    NSButton *change = [[[NSButton alloc]
        initWithFrame:NSMakeRect(376, 80, 90, 28)] autorelease];
    [change setTitle:@"Change…"];
    [change setBezelStyle:NSRoundedBezelStyle];
    [change setTarget:self];
    [change setAction:@selector(chooseFont:)];
    [content addSubview:change];

    NSTextField *note = MakeLabel(NSMakeRect(20, 24, 440, 34),
        @"Braille maps require Cascadia Code for correct alignment. "
        @"If the resolved font above is not Cascadia Code, maps may misalign.",
        NO);
    [note setFont:[NSFont systemFontOfSize:11.0]];
    [note setTextColor:[NSColor darkGrayColor]];
    // Allow the note to wrap over two lines.
    [[note cell] setWraps:YES];
    [content addSubview:note];

    [self refresh];
    return self;
}

- (void)dealloc
{
    [_fontField release];
    [super dealloc];
}

- (void)refresh
{
    [_fontField setStringValue:[DTFontManager resolvedFontDescription]];
}

- (void)showPreferences
{
    [self refresh];
    [[self window] center];
    [self showWindow:self];
    [[self window] makeKeyAndOrderFront:self];
}

- (void)chooseFont:(id)sender
{
    NSFontManager *fm = [NSFontManager sharedFontManager];
    [fm setSelectedFont:[DTFontManager documentFont] isMultiple:NO];
    // Make sure the Preferences window is key so changeFont: routes back to
    // this window controller (which is in the window's responder chain).
    [[self window] makeKeyAndOrderFront:self];
    [fm orderFrontFontPanel:self];
}

// Received via the responder chain when the user picks a font in the panel.
- (void)changeFont:(id)sender
{
    NSFont *current = [DTFontManager documentFont];
    NSFont *chosen = [sender convertFont:current];
    [DTFontManager setDocumentFont:chosen];
    [self refresh];
}

@end
