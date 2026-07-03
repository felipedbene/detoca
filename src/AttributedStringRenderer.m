//
//  AttributedStringRenderer.m
//  DeToca
//

#import "AttributedStringRenderer.h"
#import "ANSIParser.h"
#import "ANSISpan.h"
#import "ANSIPalette.h"
#import "GopherMenuParser.h"

@implementation AttributedStringRenderer

// Default foreground for text with no explicit ANSI color, chosen for a dark
// (terminal-style) background — see -[GopherWindowController buildTextView…].
// The gopher-cta maps assume a dark terminal, so uncolored glyphs must be light.
+ (NSColor *)defaultForegroundColor
{
    return [NSColor colorWithDeviceWhite:0.90 alpha:1.0];
}

+ (NSColor *)colorFromRGB:(ANSIRGB)rgb
{
    return [NSColor colorWithDeviceRed:(rgb.r / 255.0)
                                green:(rgb.g / 255.0)
                                 blue:(rgb.b / 255.0)
                                alpha:1.0];
}

+ (NSAttributedString *)attributedStringFromData:(NSData *)data font:(NSFont *)font
{
    NSString *text = [GopherMenuParser stringFromData:data];
    return [self attributedStringFromString:text font:font];
}

+ (NSAttributedString *)attributedStringFromString:(NSString *)text font:(NSFont *)font
{
    if (font == nil) {
        font = [NSFont userFixedPitchFontOfSize:12.0];
    }

    // Bold variant of the same face (falls back to the plain font if the face
    // has no bold member — Cascadia Code static Regular does not, so bold text
    // simply renders regular rather than substituting a mismatched face that
    // would break braille alignment).
    NSFontManager *fm = [NSFontManager sharedFontManager];
    NSFont *boldFont = [fm convertFont:font toHaveTrait:NSBoldFontMask];

    NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];

    NSArray *spans = [ANSIParser spansFromString:text];
    NSUInteger i, n = [spans count];
    for (i = 0; i < n; i++) {
        ANSISpan *span = [spans objectAtIndex:i];
        NSString *runText = [span text];
        if ([runText length] == 0) {
            continue;
        }

        NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
        [attrs setObject:([span bold] ? boldFont : font) forKey:NSFontAttributeName];

        if ([span hasForeground]) {
            [attrs setObject:[self colorFromRGB:[span foreground]]
                     forKey:NSForegroundColorAttributeName];
        } else {
            // Light default so uncolored text is readable on the dark background.
            [attrs setObject:[self defaultForegroundColor]
                     forKey:NSForegroundColorAttributeName];
        }
        if ([span hasBackground]) {
            [attrs setObject:[self colorFromRGB:[span background]]
                     forKey:NSBackgroundColorAttributeName];
        }

        NSAttributedString *piece = [[NSAttributedString alloc] initWithString:runText
                                                                    attributes:attrs];
        [result appendAttributedString:piece];
        [piece release];
    }

    return result;
}

@end
