//
//  PreferencesController.m
//  DeToca
//

#import "PreferencesController.h"
#import "DTFontManager.h"
#import "DTServerPrefs.h"
#import "AppDelegate.h"

@interface PreferencesController ()
- (void)refresh;
- (void)loadServerValues;
- (void)validateInputs;
- (void)chooseFont:(id)sender;
- (void)testConnection:(id)sender;
- (void)saveServer:(id)sender;
- (void)setStatus:(NSString *)text color:(NSColor *)color;
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
    NSRect frame = NSMakeRect(0, 0, 520, 340);
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

    // --- gopher-spot Server section (top) ---
    NSTextField *srvHeading = MakeLabel(NSMakeRect(20, 306, 480, 20),
        @"gopher-spot Server", YES);
    [content addSubview:srvHeading];

    NSTextField *srvSub = MakeLabel(NSMakeRect(20, 286, 480, 16),
        @"Where the radinho connects. Cmd-R and the media keys use this address.",
        NO);
    [srvSub setFont:[NSFont systemFontOfSize:11.0]];
    [srvSub setTextColor:[NSColor darkGrayColor]];
    [content addSubview:srvSub];

    NSTextField *hostLabel = MakeLabel(NSMakeRect(20, 252, 44, 22), @"Host:", NO);
    [hostLabel setAlignment:NSRightTextAlignment];
    [content addSubview:hostLabel];

    _hostField = [[NSTextField alloc] initWithFrame:NSMakeRect(70, 250, 296, 24)];
    [_hostField setBezelStyle:NSTextFieldSquareBezel];
    [[_hostField cell] setPlaceholderString:@"10.0.100.112"];
    [_hostField setDelegate:self];
    [content addSubview:_hostField];

    NSTextField *portLabel = MakeLabel(NSMakeRect(376, 252, 36, 22), @"Port:", NO);
    [portLabel setAlignment:NSRightTextAlignment];
    [content addSubview:portLabel];

    _portField = [[NSTextField alloc] initWithFrame:NSMakeRect(418, 250, 62, 24)];
    [_portField setBezelStyle:NSTextFieldSquareBezel];
    [[_portField cell] setPlaceholderString:@"70"];
    [_portField setDelegate:self];
    [content addSubview:_portField];

    _testButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, 210, 150, 30)];
    [_testButton setTitle:@"Test Connection"];
    [_testButton setBezelStyle:NSRoundedBezelStyle];
    [_testButton setTarget:self];
    [_testButton setAction:@selector(testConnection:)];
    [content addSubview:_testButton];
    [_testButton release];

    _saveButton = [[NSButton alloc] initWithFrame:NSMakeRect(400, 210, 100, 30)];
    [_saveButton setTitle:@"Save"];
    [_saveButton setBezelStyle:NSRoundedBezelStyle];
    [_saveButton setKeyEquivalent:@"\r"];   // Return activates Save
    [_saveButton setTarget:self];
    [_saveButton setAction:@selector(saveServer:)];
    [content addSubview:_saveButton];
    [_saveButton release];

    _statusLabel = [MakeLabel(NSMakeRect(20, 184, 480, 18), @"", NO) retain];
    [_statusLabel setFont:[NSFont systemFontOfSize:11.0]];
    [content addSubview:_statusLabel];

    // --- divider ---
    NSBox *divider = [[[NSBox alloc]
        initWithFrame:NSMakeRect(20, 170, 480, 1)] autorelease];
    [divider setBoxType:NSBoxSeparator];
    [content addSubview:divider];

    // --- Document Font section (bottom) ---
    NSTextField *heading = MakeLabel(NSMakeRect(20, 140, 480, 20),
        @"Document Font", YES);
    [content addSubview:heading];

    NSTextField *sub = MakeLabel(NSMakeRect(20, 118, 480, 18),
        @"Used to render text documents and ANSI/braille maps.", NO);
    [sub setFont:[NSFont systemFontOfSize:11.0]];
    [sub setTextColor:[NSColor darkGrayColor]];
    [content addSubview:sub];

    _fontField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 82, 390, 24)];
    [_fontField setEditable:NO];
    [_fontField setSelectable:YES];
    [_fontField setBezeled:YES];
    [_fontField setBezelStyle:NSTextFieldRoundedBezel];
    [content addSubview:_fontField];

    NSButton *change = [[[NSButton alloc]
        initWithFrame:NSMakeRect(416, 80, 90, 28)] autorelease];
    [change setTitle:@"Change…"];
    [change setBezelStyle:NSRoundedBezelStyle];
    [change setTarget:self];
    [change setAction:@selector(chooseFont:)];
    [content addSubview:change];

    NSTextField *note = MakeLabel(NSMakeRect(20, 24, 480, 34),
        @"Braille maps require Cascadia Code for correct alignment. "
        @"If the resolved font above is not Cascadia Code, maps may misalign.",
        NO);
    [note setFont:[NSFont systemFontOfSize:11.0]];
    [note setTextColor:[NSColor darkGrayColor]];
    [[note cell] setWraps:YES];
    [content addSubview:note];

    [self refresh];
    return self;
}

- (void)dealloc
{
    [_testRequest cancel];
    [_testRequest release];
    [_testStart release];
    [_hostField release];
    [_portField release];
    [_statusLabel release];
    [_fontField release];
    [super dealloc];
}

- (void)refresh
{
    [_fontField setStringValue:[DTFontManager resolvedFontDescription]];
    [self loadServerValues];
    [self validateInputs];
}

- (void)loadServerValues
{
    // Reflect whatever is stored now (including a legacy `defaults write`).
    [_hostField setStringValue:[DTServerPrefs host]];
    [_portField setStringValue:[NSString stringWithFormat:@"%ld",
                                (long)[DTServerPrefs port]]];
}

- (void)showPreferences
{
    [self refresh];
    [[self window] center];
    [self showWindow:self];
    [[self window] makeKeyAndOrderFront:self];
}

#pragma mark - Validation

// The Save button is enabled only for a valid host+port; Test needs the same
// and no test already running.
- (void)validateInputs
{
    NSString *host = [_hostField stringValue];
    NSInteger port = [_portField integerValue];
    BOOL valid = [DTServerPrefs isValidHost:host port:port];
    [_saveButton setEnabled:valid];
    [_testButton setEnabled:(valid && _testRequest == nil)];
}

// NSControl delegate: fires on every keystroke in either field.
- (void)controlTextDidChange:(NSNotification *)note
{
    [self setStatus:@"" color:nil];   // stale once the address is edited
    [self validateInputs];
}

#pragma mark - Test Connection

- (void)setStatus:(NSString *)text color:(NSColor *)color
{
    [_statusLabel setStringValue:(text ? text : @"")];
    [_statusLabel setTextColor:(color ? color : [NSColor darkGrayColor])];
}

- (void)testConnection:(id)sender
{
    NSString *host = [[_hostField stringValue]
                      stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSInteger port = [_portField integerValue];
    if (![DTServerPrefs isValidHost:host port:port]) {
        [self setStatus:@"Enter a valid host and port (1–65535)."
                  color:[NSColor redColor]];
        return;
    }

    // Fetch the gopher-spot root menu over the normal network path (NOT the
    // /spot/api/1 machine API). One-shot: didReceiveData: or didFailWithError:.
    [_testRequest cancel];
    [_testRequest release];
    _testRequest = [[GopherRequest requestWithHost:host port:port selector:@""] retain];
    [_testRequest setDelegate:self];

    [_testStart release];
    _testStart = [[NSDate alloc] init];

    [self setStatus:[NSString stringWithFormat:@"Testing %@:%ld…", host, (long)port]
              color:[NSColor darkGrayColor]];
    [_testButton setEnabled:NO];
    [_testRequest start];
}

- (void)gopherRequest:(GopherRequest *)request didReceiveData:(NSData *)data
{
    if (request != _testRequest) {
        return;
    }
    double ms = -[_testStart timeIntervalSinceNow] * 1000.0;
    [self setStatus:[NSString stringWithFormat:@"Connected · %.0f ms · %lu bytes",
                     ms, (unsigned long)[data length]]
              color:[NSColor colorWithCalibratedRed:0.0 green:0.5 blue:0.0 alpha:1.0]];
    [_testRequest release];
    _testRequest = nil;
    [self validateInputs];
}

- (void)gopherRequest:(GopherRequest *)request didFailWithError:(NSError *)error
{
    if (request != _testRequest) {
        return;
    }
    NSString *reason = [error localizedDescription];
    if ([reason length] == 0) {
        reason = @"connection failed";
    }
    [self setStatus:[NSString stringWithFormat:@"Failed: %@", reason]
              color:[NSColor redColor]];
    [_testRequest release];
    _testRequest = nil;
    [self validateInputs];
}

#pragma mark - Save

- (void)saveServer:(id)sender
{
    NSString *host = [_hostField stringValue];
    NSInteger port = [_portField integerValue];
    if (![DTServerPrefs isValidHost:host port:port]) {
        NSBeep();
        return;
    }

    BOOL changed = [DTServerPrefs saveHost:host port:port];
    [self loadServerValues];   // reflect the trimmed, stored form

    if (changed) {
        // Reconnect the radinho to the new backend (same path as Cmd-R).
        id delegate = [NSApp delegate];
        if ([delegate respondsToSelector:@selector(reconnectRadinho)]) {
            [delegate reconnectRadinho];
        }
        [self setStatus:@"Saved — reconnecting the radinho…"
                  color:[NSColor colorWithCalibratedRed:0.0 green:0.5 blue:0.0 alpha:1.0]];
    } else {
        [self setStatus:@"Saved (no change)."
                  color:[NSColor darkGrayColor]];
    }
}

#pragma mark - Font

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
    [_fontField setStringValue:[DTFontManager resolvedFontDescription]];
}

@end
