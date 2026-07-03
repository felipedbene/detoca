//
//  AttributedStringRenderer.h
//  DeToca
//
//  The AppKit half of the ANSI pipeline: turns the pure-Foundation ANSISpan
//  runs produced by ANSIParser into an NSAttributedString with real NSColor /
//  NSFont attributes. Kept separate so the parser stays AppKit-free and
//  unit-testable.
//

#import <Cocoa/Cocoa.h>

@interface AttributedStringRenderer : NSObject

// Render raw type-0 document bytes: decode, parse SGR, and style with the
// given monospaced font. Colors come from the ANSI 256-color palette.
+ (NSAttributedString *)attributedStringFromData:(NSData *)data font:(NSFont *)font;

// Render an already-decoded string the same way.
+ (NSAttributedString *)attributedStringFromString:(NSString *)text font:(NSFont *)font;

@end
