//
//  DTTheme.h
//  DeToca — fio 9
//
//  The one place the app's dark "CRT / radinho" look lives. Before this the dark
//  colors were inlined as literal colorWithDeviceWhite:/blackColor calls across
//  ~6 files; DTTheme centralizes that vocabulary plus a signature amber accent
//  (from the app's amber-CRT-gopher icon) and a few control factories, so the
//  player, playlist and Preferences share one coherent skin instead of looking
//  like a generic system form.
//

#import <Cocoa/Cocoa.h>

@interface DTTheme : NSObject

// --- Palette ---
+ (NSColor *)background;    // near-black window/list background
+ (NSColor *)panelInk;     // slightly lifted black for dark input fields
+ (NSColor *)textPrimary;  // primary foreground on dark (deviceWhite 0.90)
+ (NSColor *)textBright;   // emphasis (0.95)
+ (NSColor *)textDim;      // secondary (0.65)
+ (NSColor *)textMuted;    // tertiary / tags (0.55)
+ (NSColor *)textDisabled; // (0.45)
+ (NSColor *)accent;       // amber CRT glow — active / now-playing / play
+ (NSColor *)error;        // soft red
+ (NSColor *)success;      // green

// --- Fonts ---
+ (NSFont *)uiFontOfSize:(CGFloat)size;    // system font
+ (NSFont *)monoFontOfSize:(CGFloat)size;  // Cascadia Code (via DTFontManager)

// --- Control factories ---
// A borderless, non-drawing label in the given foreground color.
+ (NSTextField *)labelWithFrame:(NSRect)frame
                           size:(CGFloat)size
                          color:(NSColor *)color;
// A dark, editable text field (dark ink background, light text/caret) that reads
// as part of the CRT skin instead of a bright system field.
+ (NSTextField *)darkFieldWithFrame:(NSRect)frame;
// A textured rounded button (the HUD/transport look).
+ (NSButton *)buttonWithFrame:(NSRect)frame
                        title:(NSString *)title
                       target:(id)target
                       action:(SEL)action;

@end
