//
//  ANSIParser.h
//  DeToca
//
//  Parses ANSI SGR ("Select Graphic Rendition") escape sequences out of a
//  text document and produces an array of ANSISpan runs describing styled
//  text. Supported:
//      ESC[0m / ESC[m      reset
//      ESC[1m             bold on      ESC[22m  bold off
//      ESC[30..37m        foreground, basic       ESC[39m  default fg
//      ESC[40..47m        background, basic       ESC[49m  default bg
//      ESC[90..97m        foreground, bright
//      ESC[100..107m      background, bright
//      ESC[38;5;Nm        foreground, 256-color
//      ESC[48;5;Nm        background, 256-color
//      ESC[38;2;R;G;Bm    foreground, 24-bit (also accepted)
//      ESC[48;2;R;G;Bm    background, 24-bit
//  Every other escape sequence (unsupported SGR codes such as italic/underline,
//  and non-SGR CSI/OSC sequences like cursor moves) is stripped, never shown
//  raw. Pure Foundation, no AppKit — unit-testable with OCUnit.
//

#import <Foundation/Foundation.h>

@interface ANSIParser : NSObject

// Parse a document into an array of ANSISpan. The concatenation of every
// span's -text equals the input with all escape sequences removed.
+ (NSArray *)spansFromString:(NSString *)text;

@end
