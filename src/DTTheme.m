//
//  DTTheme.m
//  DeToca — fio 9
//

#import "DTTheme.h"
#import "DTFontManager.h"

@implementation DTTheme

+ (NSColor *)background    { return [NSColor colorWithDeviceWhite:0.06 alpha:1.0]; }
+ (NSColor *)panelInk      { return [NSColor colorWithDeviceWhite:0.13 alpha:1.0]; }
+ (NSColor *)textPrimary   { return [NSColor colorWithDeviceWhite:0.90 alpha:1.0]; }
+ (NSColor *)textBright    { return [NSColor colorWithDeviceWhite:0.95 alpha:1.0]; }
+ (NSColor *)textDim       { return [NSColor colorWithDeviceWhite:0.65 alpha:1.0]; }
+ (NSColor *)textMuted     { return [NSColor colorWithDeviceWhite:0.55 alpha:1.0]; }
+ (NSColor *)textDisabled  { return [NSColor colorWithDeviceWhite:0.45 alpha:1.0]; }
+ (NSColor *)accent        { return [NSColor colorWithDeviceRed:1.0 green:0.72 blue:0.24 alpha:1.0]; }
+ (NSColor *)error         { return [NSColor colorWithDeviceRed:1.0 green:0.45 blue:0.45 alpha:1.0]; }
+ (NSColor *)success       { return [NSColor colorWithDeviceRed:0.40 green:0.80 blue:0.45 alpha:1.0]; }

+ (NSFont *)uiFontOfSize:(CGFloat)size
{
    return [NSFont systemFontOfSize:size];
}

+ (NSFont *)monoFontOfSize:(CGFloat)size
{
    NSFont *doc = [DTFontManager documentFont];
    NSFont *sized = [NSFont fontWithName:[doc fontName] size:size];
    return sized ? sized : [NSFont userFixedPitchFontOfSize:size];
}

+ (NSTextField *)labelWithFrame:(NSRect)frame
                           size:(CGFloat)size
                          color:(NSColor *)color
{
    NSTextField *l = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [l setBezeled:NO];
    [l setBordered:NO];
    [l setEditable:NO];
    [l setSelectable:NO];
    [l setDrawsBackground:NO];
    [l setFont:[self uiFontOfSize:size]];
    [l setTextColor:(color ? color : [self textPrimary])];
    [l setStringValue:@""];
    return l;
}

+ (NSTextField *)darkFieldWithFrame:(NSRect)frame
{
    NSTextField *f = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [f setBezeled:YES];
    [f setBezelStyle:NSTextFieldSquareBezel];
    [f setDrawsBackground:YES];
    [f setBackgroundColor:[self panelInk]];
    [f setTextColor:[self textBright]];
    [f setFont:[self uiFontOfSize:12.0]];
    // Keep the insertion point / selection visible on the dark ink.
    [[f cell] setFocusRingType:NSFocusRingTypeDefault];
    return f;
}

+ (NSButton *)buttonWithFrame:(NSRect)frame
                        title:(NSString *)title
                       target:(id)target
                       action:(SEL)action
{
    NSButton *b = [[[NSButton alloc] initWithFrame:frame] autorelease];
    [b setTitle:(title ? title : @"")];
    [b setButtonType:NSMomentaryPushInButton];
    [b setBezelStyle:NSTexturedRoundedBezelStyle];
    [b setFont:[self uiFontOfSize:13.0]];
    [b setTarget:target];
    [b setAction:action];
    return b;
}

@end
