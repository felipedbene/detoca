//
//  SpotSelectors.m
//  DeToca — fio 6
//

#import "SpotSelectors.h"

@implementation SpotSelectors

+ (BOOL)isPlayActionSelector:(NSString *)selector
                    playBase:(NSString *)playBase
                 controlBase:(NSString *)controlBase
{
    if ([selector length] == 0) {
        return NO;
    }

    // The transport "play" command, e.g. /spot/control/play.
    if ([controlBase length] > 0) {
        NSString *controlPlay = [controlBase stringByAppendingString:@"/play"];
        if ([selector isEqualToString:controlPlay]) {
            return YES;
        }
    }

    // The play endpoint, e.g. /spot/play?uri=spotify:track:<id> (or /spot/play,
    // /spot/play/…). Must not match siblings like /spot/playlists — so the
    // character right after the base must be a boundary ('?' or '/') or the end.
    if ([playBase length] > 0 && [selector hasPrefix:playBase]) {
        NSString *rest = [selector substringFromIndex:[playBase length]];
        if ([rest length] == 0 ||
            [rest hasPrefix:@"?"] ||
            [rest hasPrefix:@"/"]) {
            return YES;
        }
    }

    return NO;
}

@end
