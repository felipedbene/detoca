//
//  DTMediaKeyRouter.h
//  DeToca — fio 8
//
//  Pure decode + policy for the MacBook keyboard's media keys. Splitting this
//  out of the CGEventTap (DTMediaKeyTap) keeps the decision logic — which key,
//  which action, in which state — free of AppKit/Carbon so it is unit-testable.
//
//  The tap decodes an NSSystemDefined (subtype 8) event into a raw NX_KEYTYPE_*
//  keycode plus pressed/repeat flags and asks this class what to do. Pure
//  Foundation — no IOKit, no AppKit.
//

#import <Foundation/Foundation.h>

// Raw NX_KEYTYPE_* keycodes (from <IOKit/hidsystem/ev_keymap.h>), redeclared
// here so this layer stays IOKit-free. The tap passes the same numbers.
enum {
    DTNXKeyTypePlay   = 16,   // NX_KEYTYPE_PLAY   (⏯)
    DTNXKeyTypeNext   = 19,   // NX_KEYTYPE_FAST   (⏭ / fast-forward)
    DTNXKeyTypePrev   = 20    // NX_KEYTYPE_REWIND (⏮ / rewind)
};

// The transport media keys we handle. DTMediaKeyNone means "not ours" — the
// tap should let the event pass through untouched.
typedef enum {
    DTMediaKeyNone = 0,
    DTMediaKeyPlayPause,
    DTMediaKeyNext,
    DTMediaKeyPrevious
} DTMediaKeyKind;

// What the app should do for a decoded press, given the current session state.
typedef enum {
    DTMediaKeyActionNone = 0,         // do nothing (key-up, repeat, or no-op)
    DTMediaKeyActionTogglePlayPause,  // play/pause with a live session
    DTMediaKeyActionNext,
    DTMediaKeyActionPrevious,
    DTMediaKeyActionReconnectAndPlay  // play pressed while disconnected
} DTMediaKeyAction;

@interface DTMediaKeyRouter : NSObject

// Decode a raw NX_KEYTYPE_* keycode into a media-key kind (DTMediaKeyNone if we
// don't handle it).
+ (DTMediaKeyKind)kindForKeyCode:(int)keyCode;

// Decide the action for a decoded key.
//   pressed   — YES on key-down, NO on key-up. We act on key-down only.
//   isRepeat  — YES for an auto-repeat of a held key. Ignored (one action per
//               physical press) so play/pause never double-toggles and next/prev
//               never machine-gun skip.
//   connected — YES if a gopher-spot stream session is currently active.
// With no live session, play → ReconnectAndPlay (Cmd-R + play); next/prev are a
// silent no-op.
+ (DTMediaKeyAction)actionForKind:(DTMediaKeyKind)kind
                          pressed:(BOOL)pressed
                         isRepeat:(BOOL)isRepeat
                        connected:(BOOL)connected;

@end
