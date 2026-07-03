//
//  DTMediaKeyTap.h
//  DeToca — fio 8
//
//  Global capture of the MacBook keyboard's media keys (⏮ ⏯ ⏭) via a
//  Quartz event tap, so the radinho responds to them even when DeToca is not
//  frontmost — and so the key is *consumed* and iTunes doesn't launch on ⏯.
//
//  Technique (see the fio-8 report): a kCGSessionEventTap for NX_SYSDEFINED
//  events, decoding subtype-8 aux-button presses. On 10.6 this needs no
//  "assistive devices" toggle. The tap runs on a dedicated thread with its own
//  run loop so it keeps working while a modal sheet/panel blocks the main loop.
//  Decode is delegated to DTMediaKeyRouter (pure); this class is the AppKit /
//  Quartz plumbing only. While DeToca runs it owns these keys globally.
//

#import <Cocoa/Cocoa.h>
#import "DTMediaKeyRouter.h"

@class DTMediaKeyTap;

@protocol DTMediaKeyTapDelegate <NSObject>
// Called on the main thread for every media-key event we capture (down, up,
// and repeat). The delegate applies policy via DTMediaKeyRouter. `kind` is
// never DTMediaKeyNone.
- (void)mediaKeyTap:(DTMediaKeyTap *)tap
        receivedKey:(DTMediaKeyKind)kind
            pressed:(BOOL)pressed
           isRepeat:(BOOL)isRepeat;
@end

@interface DTMediaKeyTap : NSObject {
    id <DTMediaKeyTapDelegate> _delegate;   // not retained
    CFMachPortRef  _tapPort;
    CFRunLoopSourceRef _runLoopSource;
    CFRunLoopRef   _tapRunLoop;             // the dedicated thread's run loop
    NSThread      *_thread;
}

- (id)initWithDelegate:(id <DTMediaKeyTapDelegate>)delegate;

// Install the tap and begin watching. Returns NO if the tap can't be created
// (e.g. the OS denied it); the app then simply runs without media-key support.
- (BOOL)start;

// Disable and tear down the tap. Safe to call more than once.
- (void)stop;

@end
