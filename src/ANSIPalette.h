//
//  ANSIPalette.h
//  DeToca
//
//  The standard xterm 256-color palette: 16 base colors, a 6x6x6 color cube,
//  and 24 grayscale steps. Pure Foundation (returns plain RGB byte triples);
//  the AppKit layer maps these to NSColor. Keeping it AppKit-free lets the
//  palette be unit-tested with OCUnit.
//

#import <Foundation/Foundation.h>

typedef struct {
    unsigned char r;
    unsigned char g;
    unsigned char b;
} ANSIRGB;

@interface ANSIPalette : NSObject

// RGB for a palette index 0-255. Out-of-range indices are clamped.
+ (ANSIRGB)rgbForIndex:(NSInteger)index;

@end
