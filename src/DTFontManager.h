//
//  DTFontManager.h
//  DeToca
//
//  Registers the bundled Cascadia Code font (Spike A winner: the only tested
//  font with native, correctly-aligned braille on 10.6) and vends the document
//  font used for text/ANSI rendering. The resolved font name is exposed so a
//  misconfiguration is diagnosable from the Preferences pane.
//

#import <Cocoa/Cocoa.h>

// NSUserDefaults keys for the document font preference.
extern NSString * const DTDocumentFontNameKey;
extern NSString * const DTDocumentFontSizeKey;

// The bundled default: Cascadia Code 12pt.
extern NSString * const DTDefaultFontName;

@interface DTFontManager : NSObject

// Register bundled fonts (process scope). Call once at launch.
+ (void)registerBundledFonts;

// The resolved document font from preferences, or the bundled default, or a
// last-resort monospaced fallback if neither is installed.
+ (NSFont *)documentFont;

// Persist a new document font preference.
+ (void)setDocumentFont:(NSFont *)font;

// Human-readable description of what actually resolved, e.g.
// "Cascadia Code 12.0" or "Menlo 12.0 (Cascadia Code not found!)".
+ (NSString *)resolvedFontDescription;

@end
