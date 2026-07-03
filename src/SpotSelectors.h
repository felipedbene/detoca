//
//  SpotSelectors.h
//  DeToca — fio 6
//
//  The one gopher-spot-specific heuristic in the radinho browser: deciding
//  whether activating a menu item's selector is a "play" action (so the local
//  audio stream should be ensured playing) versus plain drill-down navigation.
//  Pure Foundation — no AppKit, no gopher — so it is unit-testable.
//

#import <Foundation/Foundation.h>

@interface SpotSelectors : NSObject

// YES if `selector` triggers playback: a "/spot/play?…" action (playBase is the
// derived "…/play" sibling of the control base) or the "…/control/play"
// transport command. Must NOT match browse selectors like "/spot/playlists" or
// "/spot/track/<id>".
+ (BOOL)isPlayActionSelector:(NSString *)selector
                    playBase:(NSString *)playBase
                 controlBase:(NSString *)controlBase;

@end
