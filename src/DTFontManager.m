//
//  DTFontManager.m
//  DeToca
//

#import "DTFontManager.h"
#import <ApplicationServices/ApplicationServices.h>  // CTFontManager (10.6+)

NSString * const DTDocumentFontNameKey = @"DTDocumentFontName";
NSString * const DTDocumentFontSizeKey = @"DTDocumentFontSize";
NSString * const DTDefaultFontName     = @"Cascadia Code";

#define DT_DEFAULT_FONT_SIZE 12.0

@implementation DTFontManager

+ (void)registerBundledFonts
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"CascadiaCode-Regular"
                                                     ofType:@"ttf"];
    if (path == nil) {
        NSLog(@"DTFontManager: bundled CascadiaCode-Regular.ttf not found in Resources.");
        return;
    }

    NSURL *url = [NSURL fileURLWithPath:path];
    CFErrorRef error = NULL;
    // 10.6-only: CTFontManagerRegisterFontsForURL. Process scope keeps the
    // font private to DeToca (no system-wide install).
    bool ok = CTFontManagerRegisterFontsForURL((CFURLRef)url,
                                               kCTFontManagerScopeProcess,
                                               &error);
    if (!ok) {
        // Already-registered is not a real failure; log anything else.
        if (error != NULL) {
            NSLog(@"DTFontManager: font registration issue: %@", (NSError *)error);
            CFRelease(error);
        }
    }
}

+ (CGFloat)defaultSize
{
    NSNumber *n = [[NSUserDefaults standardUserDefaults] objectForKey:DTDocumentFontSizeKey];
    if (n != nil && [n doubleValue] > 0) {
        return (CGFloat)[n doubleValue];
    }
    return DT_DEFAULT_FONT_SIZE;
}

+ (NSFont *)documentFont
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *name = [d objectForKey:DTDocumentFontNameKey];
    if (name == nil) {
        name = DTDefaultFontName;
    }
    CGFloat size = [self defaultSize];

    NSFont *font = [NSFont fontWithName:name size:size];
    if (font != nil) {
        return font;
    }
    // Preferred name missing: try the bundled default explicitly.
    font = [NSFont fontWithName:DTDefaultFontName size:size];
    if (font != nil) {
        return font;
    }
    // Last resort: a monospaced font that ships with 10.6.
    font = [NSFont fontWithName:@"Menlo" size:size];
    if (font != nil) {
        return font;
    }
    return [NSFont userFixedPitchFontOfSize:size];
}

+ (void)setDocumentFont:(NSFont *)font
{
    if (font == nil) {
        return;
    }
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:[font fontName] forKey:DTDocumentFontNameKey];
    [d setDouble:(double)[font pointSize] forKey:DTDocumentFontSizeKey];
    [d synchronize];
}

+ (NSString *)resolvedFontDescription
{
    NSFont *font = [self documentFont];
    NSString *resolved = [font fontName];
    CGFloat size = [font pointSize];

    // Was Cascadia Code actually available? If the resolved font isn't the
    // bundled one, surface that so alignment problems are obvious.
    BOOL cascadiaPresent = ([NSFont fontWithName:DTDefaultFontName size:size] != nil);
    if (!cascadiaPresent) {
        return [NSString stringWithFormat:@"%@ %.1f  (Cascadia Code not found!)",
                resolved, (double)size];
    }
    return [NSString stringWithFormat:@"%@ %.1f", resolved, (double)size];
}

@end
