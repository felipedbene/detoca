//
//  AppDelegate.m
//  DeToca
//

#import "AppDelegate.h"
#import "GopherResource.h"
#import "GopherItem.h"
#import "GopherWindowController.h"
#import "PreferencesController.h"
#import "BookmarkStore.h"
#import "DTFontManager.h"
#import "DTInputSheet.h"

#define DT_HOME_HOST @"gopher.debene.dev"
#define DT_HOME_PORT 70

@interface AppDelegate ()
- (void)buildMenuBar;
- (void)addSubmenu:(NSMenu *)submenu toMainMenu:(NSMenu *)mainMenu;
- (NSMenuItem *)addItemTo:(NSMenu *)menu
                    title:(NSString *)title
                   action:(SEL)action
                      key:(NSString *)key
                   target:(id)target;
@end

@implementation AppDelegate

@synthesize initialURLString = _initialURLString;

- (id)init
{
    self = [super init];
    if (self != nil) {
        _controllers = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_controllers release];
    [_prefs release];
    [_initialURLString release];
    [super dealloc];
}

#pragma mark - App lifecycle

- (void)applicationWillFinishLaunching:(NSNotification *)note
{
    [DTFontManager registerBundledFonts];
    [BookmarkStore ensureExists];
    [self buildMenuBar];
}

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
    // Open a location passed on the command line, otherwise Home, so the app
    // isn't blank on launch.
    if ([_initialURLString length] > 0) {
        GopherResource *res = [GopherResource resourceFromLocationString:_initialURLString];
        if (res != nil) {
            [self openResource:res fromWindow:nil];
            return;
        }
    }
    [self openHome:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app
{
    // Keep running with the menu bar; the user navigates via Home / Open
    // Location / Bookmarks even with no windows open.
    return NO;
}

#pragma mark - Navigation

- (GopherWindowController *)openResource:(GopherResource *)resource
                              fromWindow:(NSWindow *)parent
{
    GopherWindowController *c =
        [[GopherWindowController alloc] initWithResource:resource parentWindow:parent];
    [_controllers addObject:c];
    [c showWindow:self];
    [[c window] makeKeyAndOrderFront:self];
    [c startFetch];
    [c release];   // retained by _controllers
    return c;
}

- (void)openItem:(GopherItem *)item fromWindow:(NSWindow *)parent
{
    GopherItemKind kind = [item kind];

    if (kind == GopherItemKindHTML) {
        [self openExternalURLString:[item externalURLString]];
        return;
    }

    if (kind == GopherItemKindSearch) {
        NSString *prompt = [NSString stringWithFormat:@"Search “%@”:",
                            [item displayString]];
        [DTInputSheet promptOnWindow:parent
                               title:@"Gopher Search"
                             message:prompt
                        defaultValue:nil
                         placeholder:@"search terms"
                          completion:^(NSString *query) {
            if (query == nil || [query length] == 0) {
                return;  // cancelled or empty
            }
            // Type-7 request: "selector<TAB>query"; the result is a menu.
            NSString *sel = [NSString stringWithFormat:@"%@\t%@",
                             [item selector], query];
            NSString *disp = [NSString stringWithFormat:@"%@: %@",
                              [item displayString], query];
            GopherResource *res = [GopherResource resourceWithHost:[item host]
                                                              port:[item port]
                                                              type:'1'
                                                          selector:sel
                                                           display:disp];
            [self openResource:res fromWindow:parent];
        }];
        return;
    }

    // Text (0) or menu (1): open a new cascaded window.
    if (kind == GopherItemKindText || kind == GopherItemKindMenu) {
        GopherResource *res = [GopherResource resourceWithItem:item];
        [self openResource:res fromWindow:parent];
    }
}

- (void)openExternalURLString:(NSString *)urlString
{
    if ([urlString length] == 0) {
        return;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (url == nil) {
        // Percent-escape as a fallback for URLs with unsafe characters.
        NSString *escaped = [urlString stringByAddingPercentEscapesUsingEncoding:
                             NSUTF8StringEncoding];
        url = [NSURL URLWithString:escaped];
    }
    if (url != nil) {
        [[NSWorkspace sharedWorkspace] openURL:url];
    } else {
        NSBeep();
    }
}

- (void)gopherWindowWillClose:(GopherWindowController *)controller
{
    // Defer the release so we don't drop the controller in the middle of its
    // own -windowWillClose: notification.
    [[controller retain] autorelease];
    [_controllers removeObject:controller];
}

#pragma mark - Actions

- (void)openHome:(id)sender
{
    GopherResource *res = [GopherResource resourceWithHost:DT_HOME_HOST
                                                      port:DT_HOME_PORT
                                                      type:'1'
                                                  selector:@""
                                                   display:DT_HOME_HOST];
    [self openResource:res fromWindow:[NSApp keyWindow]];
}

- (void)openLocation:(id)sender
{
    [DTInputSheet promptOnWindow:[NSApp keyWindow]
                           title:@"Open Location"
                         message:@"Enter a Gopher URL or host/selector:"
                    defaultValue:@"gopher://"
                     placeholder:@"gopher://host/1/selector"
                      completion:^(NSString *location) {
        if (location == nil) {
            return;
        }
        GopherResource *res = [GopherResource resourceFromLocationString:location];
        if (res == nil) {
            NSBeep();
            return;
        }
        [self openResource:res fromWindow:[NSApp keyWindow]];
    }];
}

- (void)showBookmarks:(id)sender
{
    NSString *text = [BookmarkStore bookmarksText];
    GopherResource *res = [GopherResource resourceWithHost:@""
                                                      port:70
                                                      type:'1'
                                                  selector:@""
                                                   display:@"Bookmarks"];
    GopherWindowController *c =
        [[GopherWindowController alloc] initWithResource:res
                                            parentWindow:[NSApp keyWindow]];
    [_controllers addObject:c];
    [c showWindow:self];
    [[c window] makeKeyAndOrderFront:self];
    [c loadLocalMenuText:text];
    [c release];
}

- (void)addBookmark:(id)sender
{
    id wc = [[NSApp keyWindow] windowController];
    if (![wc isKindOfClass:[GopherWindowController class]]) {
        NSBeep();
        return;
    }
    GopherResource *res = [(GopherWindowController *)wc resource];
    if (res == nil || [[res host] length] == 0) {
        NSBeep();
        return;
    }
    if (![BookmarkStore addBookmarkForResource:res]) {
        NSBeep();
    }
}

- (void)showPreferences:(id)sender
{
    if (_prefs == nil) {
        _prefs = [[PreferencesController alloc] init];
    }
    [_prefs showPreferences];
}

#pragma mark - Menu validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if ([menuItem action] == @selector(addBookmark:)) {
        id wc = [[NSApp keyWindow] windowController];
        if (![wc isKindOfClass:[GopherWindowController class]]) {
            return NO;
        }
        GopherResource *res = [(GopherWindowController *)wc resource];
        return (res != nil && [[res host] length] > 0);
    }
    return YES;
}

#pragma mark - Menu bar (built in code; no NIB)

- (NSMenuItem *)addItemTo:(NSMenu *)menu
                    title:(NSString *)title
                   action:(SEL)action
                      key:(NSString *)key
                   target:(id)target
{
    NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:title
                                                   action:action
                                            keyEquivalent:(key ? key : @"")] autorelease];
    if (target != nil) {
        [item setTarget:target];
    }
    [menu addItem:item];
    return item;
}

- (void)buildMenuBar
{
    NSMenu *mainMenu = [[[NSMenu alloc] initWithTitle:@"MainMenu"] autorelease];

    // --- Application menu ---
    NSMenuItem *appItem = [[[NSMenuItem alloc] init] autorelease];
    [mainMenu addItem:appItem];
    NSMenu *appMenu = [[[NSMenu alloc] initWithTitle:@"DeToca"] autorelease];
    [appItem setSubmenu:appMenu];

    [self addItemTo:appMenu title:@"About DeToca"
             action:@selector(orderFrontStandardAboutPanel:) key:@"" target:nil];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [self addItemTo:appMenu title:@"Preferences…"
             action:@selector(showPreferences:) key:@"," target:self];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [self addItemTo:appMenu title:@"Hide DeToca"
             action:@selector(hide:) key:@"h" target:nil];
    NSMenuItem *hideOthers = [self addItemTo:appMenu title:@"Hide Others"
             action:@selector(hideOtherApplications:) key:@"h" target:nil];
    [hideOthers setKeyEquivalentModifierMask:(NSCommandKeyMask | NSAlternateKeyMask)];
    [self addItemTo:appMenu title:@"Show All"
             action:@selector(unhideAllApplications:) key:@"" target:nil];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [self addItemTo:appMenu title:@"Quit DeToca"
             action:@selector(terminate:) key:@"q" target:nil];

    // --- File menu ---
    NSMenu *fileMenu = [[[NSMenu alloc] initWithTitle:@"File"] autorelease];
    [self addSubmenu:fileMenu toMainMenu:mainMenu];
    [self addItemTo:fileMenu title:@"Open Location…"
             action:@selector(openLocation:) key:@"l" target:self];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [self addItemTo:fileMenu title:@"Close"
             action:@selector(performClose:) key:@"w" target:nil];

    // --- Edit menu (so text views get Copy / Select All) ---
    NSMenu *editMenu = [[[NSMenu alloc] initWithTitle:@"Edit"] autorelease];
    [self addSubmenu:editMenu toMainMenu:mainMenu];
    [self addItemTo:editMenu title:@"Cut" action:@selector(cut:) key:@"x" target:nil];
    [self addItemTo:editMenu title:@"Copy" action:@selector(copy:) key:@"c" target:nil];
    [self addItemTo:editMenu title:@"Paste" action:@selector(paste:) key:@"v" target:nil];
    [self addItemTo:editMenu title:@"Select All"
             action:@selector(selectAll:) key:@"a" target:nil];

    // --- Go menu ---
    NSMenu *goMenu = [[[NSMenu alloc] initWithTitle:@"Go"] autorelease];
    [self addSubmenu:goMenu toMainMenu:mainMenu];
    [self addItemTo:goMenu title:@"Home"
             action:@selector(openHome:) key:@"H" target:self];

    // --- Bookmarks menu ---
    NSMenu *bmMenu = [[[NSMenu alloc] initWithTitle:@"Bookmarks"] autorelease];
    [self addSubmenu:bmMenu toMainMenu:mainMenu];
    [self addItemTo:bmMenu title:@"Add Bookmark"
             action:@selector(addBookmark:) key:@"d" target:self];
    [self addItemTo:bmMenu title:@"Show Bookmarks"
             action:@selector(showBookmarks:) key:@"" target:self];

    // --- Window menu ---
    NSMenu *windowMenu = [[[NSMenu alloc] initWithTitle:@"Window"] autorelease];
    [self addSubmenu:windowMenu toMainMenu:mainMenu];
    [self addItemTo:windowMenu title:@"Minimize"
             action:@selector(performMiniaturize:) key:@"m" target:nil];
    [self addItemTo:windowMenu title:@"Zoom"
             action:@selector(performZoom:) key:@"" target:nil];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [self addItemTo:windowMenu title:@"Bring All to Front"
             action:@selector(arrangeInFront:) key:@"" target:nil];

    [NSApp setMainMenu:mainMenu];
    [NSApp setWindowsMenu:windowMenu];
}

// Attach a titled submenu to the main menu via a carrier item.
- (void)addSubmenu:(NSMenu *)submenu toMainMenu:(NSMenu *)mainMenu
{
    NSMenuItem *carrier = [[[NSMenuItem alloc] initWithTitle:[submenu title]
                                                      action:NULL
                                               keyEquivalent:@""] autorelease];
    [carrier setSubmenu:submenu];
    [mainMenu addItem:carrier];
}

@end
