//
//  GopherSpotControl.h
//  DeToca — fio 5
//
//  The gopher side of gopher-spot. Created when a type-`s` sound item is
//  activated: it fetches the item's selector (a PLS) over gopher, extracts the
//  stream URL, hands it to the radinho, and then acts as the radinho's
//  StreamControlDelegate — turning play/pause/next/prev into gopher
//  /spot/control/* requests and polling /spot/now to push the now-playing title
//  back into the panel.
//
//  This is where all gopher knowledge for streaming lives, so
//  StreamPlayerController stays gopher-agnostic. Control selectors are derived
//  by convention from the stream selector's parent directory:
//    /spot/stream.pls -> /spot/control/{play,pause,next,prev}, /spot/now
//

#import <Foundation/Foundation.h>
#import "StreamPlayerController.h"
#import "GopherRequest.h"

@class GopherItem;

@interface GopherSpotControl : NSObject <StreamControlDelegate, GopherRequestDelegate> {
    NSString      *_host;
    NSInteger      _port;
    NSString      *_streamSelector;   // the type-s selector (a .pls)
    NSString      *_controlBase;      // e.g. /spot/control
    NSString      *_nowSelector;      // e.g. /spot/now
    NSString      *_title;            // display string of the sound item

    StreamPlayerController *_player;  // not retained
    GopherRequest *_pollRequest;      // retained
    NSTimer       *_pollTimer;        // retained
    BOOL           _resolving;
}

- (id)initWithSoundItem:(GopherItem *)item
                 player:(StreamPlayerController *)player;

// Fetch the PLS, resolve the stream URL, and start playback + control.
- (void)begin;

@end
