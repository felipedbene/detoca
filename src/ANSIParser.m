//
//  ANSIParser.m
//  DeToca
//

#import "ANSIParser.h"
#import "ANSISpan.h"
#import "ANSIPalette.h"

#define ANSI_ESC 0x1B
#define ANSI_BEL 0x07

// Emit the accumulated run (if any) as a span carrying the current attributes,
// then reset the run length to zero.
static void FlushRun(NSMutableArray *spans,
                     const unichar *runBuf, NSUInteger *runLen,
                     BOOL bold,
                     BOOL hasFG, ANSIRGB fg,
                     BOOL hasBG, ANSIRGB bg)
{
    if (*runLen == 0) {
        return;
    }
    ANSISpan *span = [[ANSISpan alloc] init];
    NSString *t = [[NSString alloc] initWithCharacters:runBuf length:*runLen];
    [span setText:t];
    [t release];
    [span setBold:bold];
    [span setHasForeground:hasFG];
    [span setForeground:fg];
    [span setHasBackground:hasBG];
    [span setBackground:bg];
    [spans addObject:span];
    [span release];
    *runLen = 0;
}

@implementation ANSIParser

+ (NSArray *)spansFromString:(NSString *)text
{
    NSMutableArray *spans = [NSMutableArray array];
    if (text == nil) {
        return spans;
    }

    NSUInteger len = [text length];
    if (len == 0) {
        return spans;
    }

    unichar *chars = (unichar *)malloc(len * sizeof(unichar));
    unichar *runBuf = (unichar *)malloc(len * sizeof(unichar));
    if (chars == NULL || runBuf == NULL) {
        free(chars);
        free(runBuf);
        return spans;
    }
    [text getCharacters:chars range:NSMakeRange(0, len)];
    NSUInteger runLen = 0;

    // Current SGR state.
    BOOL bold = NO;
    BOOL hasFG = NO;  ANSIRGB fg = {0, 0, 0};
    BOOL hasBG = NO;  ANSIRGB bg = {0, 0, 0};

    NSUInteger i = 0;
    while (i < len) {
        unichar c = chars[i];

        if (c != ANSI_ESC) {
            runBuf[runLen++] = c;
            i++;
            continue;
        }

        // We are at an ESC. Decide what kind of escape this is.
        if (i + 1 >= len) {
            // Lone trailing ESC: strip it.
            i++;
            break;
        }

        unichar next = chars[i + 1];

        if (next == '[') {
            // CSI sequence: parameters (0x30-0x3F) and intermediates
            // (0x20-0x2F) until a final byte (0x40-0x7E).
            NSUInteger j = i + 2;
            NSUInteger paramStart = j;
            while (j < len) {
                unichar b = chars[j];
                if (b >= 0x40 && b <= 0x7E) {
                    break; // final byte
                }
                j++;
            }

            if (j >= len) {
                // Unterminated CSI: strip to end.
                i = len;
                break;
            }

            unichar finalByte = chars[j];
            if (finalByte == 'm') {
                // SGR. Flush text accumulated under the OLD attributes first.
                FlushRun(spans, runBuf, &runLen, bold, hasFG, fg, hasBG, bg);

                // Parse the parameter substring [paramStart, j).
                NSString *paramStr = [[NSString alloc]
                                      initWithCharacters:(chars + paramStart)
                                      length:(j - paramStart)];
                NSArray *parts = [paramStr componentsSeparatedByString:@";"];
                [paramStr release];

                NSUInteger np = [parts count];
                // Convert to an int array for cursor-based consumption.
                NSInteger *codes = (NSInteger *)malloc((np > 0 ? np : 1) * sizeof(NSInteger));
                NSUInteger p;
                for (p = 0; p < np; p++) {
                    codes[p] = [[parts objectAtIndex:p] integerValue];
                }
                // "ESC[m" yields a single empty component -> treated as reset.

                NSUInteger k = 0;
                while (k < np) {
                    NSInteger code = codes[k];
                    if (code == 0) {
                        bold = NO; hasFG = NO; hasBG = NO;
                        k++;
                    } else if (code == 1) {
                        bold = YES; k++;
                    } else if (code == 22) {
                        bold = NO; k++;
                    } else if (code >= 30 && code <= 37) {
                        hasFG = YES; fg = [ANSIPalette rgbForIndex:(code - 30)];
                        k++;
                    } else if (code == 39) {
                        hasFG = NO; k++;
                    } else if (code >= 40 && code <= 47) {
                        hasBG = YES; bg = [ANSIPalette rgbForIndex:(code - 40)];
                        k++;
                    } else if (code == 49) {
                        hasBG = NO; k++;
                    } else if (code >= 90 && code <= 97) {
                        hasFG = YES; fg = [ANSIPalette rgbForIndex:(code - 90 + 8)];
                        k++;
                    } else if (code >= 100 && code <= 107) {
                        hasBG = YES; bg = [ANSIPalette rgbForIndex:(code - 100 + 8)];
                        k++;
                    } else if (code == 38 || code == 48) {
                        BOOL isFG = (code == 38);
                        // Extended color. Must consume the sub-parameters
                        // exactly so following codes are not misread (this is
                        // the fbterm "case 38" bug we must avoid).
                        if (k + 1 < np && codes[k + 1] == 5) {
                            if (k + 2 < np) {
                                ANSIRGB rgb = [ANSIPalette rgbForIndex:codes[k + 2]];
                                if (isFG) { hasFG = YES; fg = rgb; }
                                else      { hasBG = YES; bg = rgb; }
                            }
                            k += 3;
                        } else if (k + 1 < np && codes[k + 1] == 2) {
                            if (k + 4 < np) {
                                ANSIRGB rgb;
                                rgb.r = (unsigned char)codes[k + 2];
                                rgb.g = (unsigned char)codes[k + 3];
                                rgb.b = (unsigned char)codes[k + 4];
                                if (isFG) { hasFG = YES; fg = rgb; }
                                else      { hasBG = YES; bg = rgb; }
                            }
                            k += 5;
                        } else {
                            // Malformed extended-color intro: skip only this
                            // code, not the parameters that follow it.
                            k++;
                        }
                    } else {
                        // Unsupported SGR code (italic, underline, blink, ...):
                        // ignore, keeping current attributes.
                        k++;
                    }
                }

                free(codes);
            }
            // Non-SGR CSI (finalByte != 'm'): stripped, no state change,
            // no flush (surrounding text keeps its attributes).

            i = j + 1;
            continue;
        }
        else if (next == ']') {
            // OSC: strip until BEL or ST (ESC '\') or end.
            NSUInteger j = i + 2;
            while (j < len) {
                if (chars[j] == ANSI_BEL) {
                    j++;
                    break;
                }
                if (chars[j] == ANSI_ESC && j + 1 < len && chars[j + 1] == '\\') {
                    j += 2;
                    break;
                }
                j++;
            }
            i = j;
            continue;
        }
        else {
            // Two-character escape (ESC + one byte) or unknown: strip both.
            i += 2;
            continue;
        }
    }

    // Flush any trailing text.
    FlushRun(spans, runBuf, &runLen, bold, hasFG, fg, hasBG, bg);

    free(chars);
    free(runBuf);
    return spans;
}

@end
