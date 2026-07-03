//
//  GopherTableView.m
//  DeToca
//

#import "GopherTableView.h"

@implementation GopherTableView

- (void)keyDown:(NSEvent *)event
{
    NSString *chars = [event charactersIgnoringModifiers];
    if ([chars length] == 1) {
        unichar c = [chars characterAtIndex:0];
        if (c == NSCarriageReturnCharacter || c == NSEnterCharacter || c == NSNewlineCharacter) {
            if ([self selectedRow] >= 0 && [self doubleAction] != NULL) {
                [self sendAction:[self doubleAction] to:[self target]];
                return;
            }
        }
    }
    [super keyDown:event];
}

@end
