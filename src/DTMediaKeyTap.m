//
//  DTMediaKeyTap.m
//  DeToca — fio 8
//

#import "DTMediaKeyTap.h"
#import "DTDispatch.h"
#import <ApplicationServices/ApplicationServices.h>

// NX_SYSDEFINED (IOKit/hidsystem/IOLLEvent.h) — the CGEventType for
// system-defined events. Redeclared to keep this file's imports light.
#ifndef NX_SYSDEFINED
#define NX_SYSDEFINED 14
#endif

// NSEvent subtype for the aux media buttons, and the key-down state nibble.
#define DT_SUBTYPE_AUX_BUTTONS 8
#define DT_KEYSTATE_DOWN       0x0A

// Forward decl of the C tap callback.
static CGEventRef DTMediaKeyTapCallback(CGEventTapProxy proxy,
                                        CGEventType type,
                                        CGEventRef event,
                                        void *refcon);

@interface DTMediaKeyTap ()
- (void)tapThreadMain;
- (CGEventRef)handleCGEvent:(CGEventRef)event ofType:(CGEventType)type;
@end

@implementation DTMediaKeyTap

- (id)initWithDelegate:(id <DTMediaKeyTapDelegate>)delegate
{
    self = [super init];
    if (self != nil) {
        _delegate = delegate;   // not retained (the AppDelegate owns us)
    }
    return self;
}

- (void)dealloc
{
    [self stop];
    [super dealloc];
}

- (BOOL)start
{
    if (_tapPort != NULL) {
        return YES;   // already running
    }

    // Listen (and consume) system-defined events at the session level.
    CGEventMask mask = CGEventMaskBit(NX_SYSDEFINED);
    _tapPort = CGEventTapCreate(kCGSessionEventTap,
                                kCGHeadInsertEventTap,
                                kCGEventTapOptionDefault,
                                mask,
                                DTMediaKeyTapCallback,
                                self);
    if (_tapPort == NULL) {
        NSLog(@"[mediakeys] event tap denied — media keys disabled");
        return NO;   // denied — run without media-key support
    }
    NSLog(@"[mediakeys] event tap installed (session tap, NX_SYSDEFINED)");

    _thread = [[NSThread alloc] initWithTarget:self
                                      selector:@selector(tapThreadMain)
                                        object:nil];
    [_thread setName:@"dev.debene.detoca.mediakeytap"];
    [_thread start];
    return YES;
}

// Runs on the dedicated thread: pump a run loop that services the tap. Keeping
// it off the main run loop means modal sheets/panels don't stall media keys.
- (void)tapThreadMain
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    _tapRunLoop = (CFRunLoopRef)CFRetain(CFRunLoopGetCurrent());
    _runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _tapPort, 0);
    CFRunLoopAddSource(_tapRunLoop, _runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(_tapPort, true);

    [pool drain];
    CFRunLoopRun();   // blocks until -stop calls CFRunLoopStop

    // Run loop stopped: tear everything down on this thread.
    pool = [[NSAutoreleasePool alloc] init];
    if (_runLoopSource != NULL) {
        CFRunLoopRemoveSource(_tapRunLoop, _runLoopSource, kCFRunLoopCommonModes);
        CFRelease(_runLoopSource);
        _runLoopSource = NULL;
    }
    if (_tapPort != NULL) {
        CFMachPortInvalidate(_tapPort);
        CFRelease(_tapPort);
        _tapPort = NULL;
    }
    if (_tapRunLoop != NULL) {
        CFRelease(_tapRunLoop);
        _tapRunLoop = NULL;
    }
    [pool drain];
}

- (void)stop
{
    if (_tapPort != NULL) {
        CGEventTapEnable(_tapPort, false);
    }
    // Break the dedicated thread's run loop; it then frees the tap resources.
    if (_tapRunLoop != NULL) {
        CFRunLoopStop(_tapRunLoop);
    }
    [_thread release];
    _thread = nil;
}

// Called from the C callback (on the tap thread). Returns the event to pass it
// through, or NULL to consume it.
- (CGEventRef)handleCGEvent:(CGEventRef)event ofType:(CGEventType)type
{
    // The system disables a slow/interrupted tap; just re-enable and move on.
    if (type == kCGEventTapDisabledByTimeout ||
        type == kCGEventTapDisabledByUserInput) {
        if (_tapPort != NULL) {
            CGEventTapEnable(_tapPort, true);
        }
        return event;
    }

    if (type != NX_SYSDEFINED) {
        return event;
    }

    NSEvent *ns = nil;
    @try {
        ns = [NSEvent eventWithCGEvent:event];
    }
    @catch (NSException *e) {
        return event;   // not an event we can read — leave it alone
    }
    if (ns == nil || [ns subtype] != DT_SUBTYPE_AUX_BUTTONS) {
        return event;
    }

    int data1     = (int)[ns data1];
    int keyCode   = (data1 & 0xFFFF0000) >> 16;
    int keyFlags  = (data1 & 0x0000FFFF);
    BOOL pressed  = (((keyFlags & 0xFF00) >> 8) == DT_KEYSTATE_DOWN);
    BOOL isRepeat = (keyFlags & 0x1) != 0;

    DTMediaKeyKind kind = [DTMediaKeyRouter kindForKeyCode:keyCode];
    if (kind == DTMediaKeyNone) {
        return event;   // volume, brightness, etc. — not ours
    }

    // Ours: notify the delegate on the main thread (through the app's single
    // libdispatch funnel), and consume the event so it never reaches iTunes'
    // remote-control daemon.
    id <DTMediaKeyTapDelegate> delegate = _delegate;
    DTMediaKeyTap *tap = self;
    DTAsyncMain(^{
        [delegate mediaKeyTap:tap
                  receivedKey:kind
                      pressed:pressed
                     isRepeat:isRepeat];
    });
    return NULL;
}

@end

static CGEventRef DTMediaKeyTapCallback(CGEventTapProxy proxy,
                                        CGEventType type,
                                        CGEventRef event,
                                        void *refcon)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    DTMediaKeyTap *tap = (DTMediaKeyTap *)refcon;
    CGEventRef result = [tap handleCGEvent:event ofType:type];
    [pool drain];
    return result;
}
