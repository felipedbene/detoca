//
//  ANSISpan.h
//  DeToca
//
//  A run of text sharing one set of SGR attributes. The ANSIParser emits an
//  array of these; the AppKit layer turns each into NSAttributedString
//  attributes. Colors are stored as resolved RGB byte triples so this type,
//  and the parser that produces it, stay free of AppKit (NSColor).
//

#import <Foundation/Foundation.h>
#import "ANSIPalette.h"

@interface ANSISpan : NSObject {
    NSString  *_text;
    BOOL       _bold;
    BOOL       _hasForeground;
    ANSIRGB    _foreground;
    BOOL       _hasBackground;
    ANSIRGB    _background;
}

@property (nonatomic, copy)   NSString *text;
@property (nonatomic, assign) BOOL      bold;
@property (nonatomic, assign) BOOL      hasForeground;
@property (nonatomic, assign) ANSIRGB   foreground;
@property (nonatomic, assign) BOOL      hasBackground;
@property (nonatomic, assign) ANSIRGB   background;

@end
