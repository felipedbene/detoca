//
//  ANSIPalette.m
//  DeToca
//

#import "ANSIPalette.h"

// The 16 base colors (xterm defaults). Indices 0-7 normal, 8-15 bright.
static const ANSIRGB kBase16[16] = {
    {0x00, 0x00, 0x00}, // 0  black
    {0x80, 0x00, 0x00}, // 1  red
    {0x00, 0x80, 0x00}, // 2  green
    {0x80, 0x80, 0x00}, // 3  yellow
    {0x00, 0x00, 0x80}, // 4  blue
    {0x80, 0x00, 0x80}, // 5  magenta
    {0x00, 0x80, 0x80}, // 6  cyan
    {0xc0, 0xc0, 0xc0}, // 7  white (light grey)
    {0x80, 0x80, 0x80}, // 8  bright black (dark grey)
    {0xff, 0x00, 0x00}, // 9  bright red
    {0x00, 0xff, 0x00}, // 10 bright green
    {0xff, 0xff, 0x00}, // 11 bright yellow
    {0x00, 0x00, 0xff}, // 12 bright blue
    {0xff, 0x00, 0xff}, // 13 bright magenta
    {0x00, 0xff, 0xff}, // 14 bright cyan
    {0xff, 0xff, 0xff}  // 15 bright white
};

@implementation ANSIPalette

+ (ANSIRGB)rgbForIndex:(NSInteger)index
{
    if (index < 0) {
        index = 0;
    }
    if (index > 255) {
        index = 255;
    }

    if (index < 16) {
        return kBase16[index];
    }

    if (index < 232) {
        // 6x6x6 cube. Each channel level v in 0..5 maps to 0 for v==0,
        // else 55 + v*40 (yields 0,95,135,175,215,255).
        NSInteger n = index - 16;
        NSInteger ri = (n / 36) % 6;
        NSInteger gi = (n / 6) % 6;
        NSInteger bi = n % 6;

        ANSIRGB c;
        c.r = (unsigned char)(ri == 0 ? 0 : 55 + ri * 40);
        c.g = (unsigned char)(gi == 0 ? 0 : 55 + gi * 40);
        c.b = (unsigned char)(bi == 0 ? 0 : 55 + bi * 40);
        return c;
    }

    // Grayscale ramp: 24 steps from 8 to 238 in increments of 10.
    NSInteger level = 8 + (index - 232) * 10;
    ANSIRGB c;
    c.r = (unsigned char)level;
    c.g = (unsigned char)level;
    c.b = (unsigned char)level;
    return c;
}

@end
