//
//  DTMediaKeyRouter.m
//  DeToca — fio 8
//

#import "DTMediaKeyRouter.h"

@implementation DTMediaKeyRouter

+ (DTMediaKeyKind)kindForKeyCode:(int)keyCode
{
    switch (keyCode) {
        case DTNXKeyTypePlay: return DTMediaKeyPlayPause;
        case DTNXKeyTypeNext: return DTMediaKeyNext;
        case DTNXKeyTypePrev: return DTMediaKeyPrevious;
        default:              return DTMediaKeyNone;
    }
}

+ (DTMediaKeyAction)actionForKind:(DTMediaKeyKind)kind
                          pressed:(BOOL)pressed
                         isRepeat:(BOOL)isRepeat
                        connected:(BOOL)connected
{
    // Key-down only, one action per physical press.
    if (!pressed || isRepeat) {
        return DTMediaKeyActionNone;
    }

    switch (kind) {
        case DTMediaKeyPlayPause:
            // Play while connected toggles; while disconnected it revives the
            // radinho and starts playback (equivalent to Cmd-R + play).
            return connected ? DTMediaKeyActionTogglePlayPause
                             : DTMediaKeyActionReconnectAndPlay;
        case DTMediaKeyNext:
            // Skipping only makes sense with a live session.
            return connected ? DTMediaKeyActionNext : DTMediaKeyActionNone;
        case DTMediaKeyPrevious:
            return connected ? DTMediaKeyActionPrevious : DTMediaKeyActionNone;
        case DTMediaKeyNone:
        default:
            return DTMediaKeyActionNone;
    }
}

@end
