//
//  ANSISpan.m
//  DeToca
//

#import "ANSISpan.h"

@implementation ANSISpan

@synthesize text = _text;
@synthesize bold = _bold;
@synthesize hasForeground = _hasForeground;
@synthesize foreground = _foreground;
@synthesize hasBackground = _hasBackground;
@synthesize background = _background;

- (void)dealloc
{
    [_text release];
    [super dealloc];
}

@end
