//
//  PreferencesController.h
//  DeToca
//
//  The Preferences window. Two sections:
//    - gopher-spot Server (fio 8): the backend host/port the radinho connects
//      to, with live validation, a non-blocking "Test Connection", and a Save
//      that reconnects the radinho when the address changes.
//    - Document Font: the resolved font used for text/ANSI/braille rendering.
//

#import <Cocoa/Cocoa.h>
#import "GopherRequest.h"

@interface PreferencesController : NSWindowController
    <GopherRequestDelegate, NSTextFieldDelegate> {
    // Server section.
    NSTextField *_hostField;
    NSTextField *_portField;
    NSButton    *_testButton;
    NSButton    *_saveButton;
    NSTextField *_statusLabel;
    GopherRequest *_testRequest;   // in-flight connection test (retained)
    NSDate      *_testStart;       // for latency measurement

    // Font section.
    NSTextField *_fontField;
}

// Build (once) and show the Preferences window.
- (void)showPreferences;

@end
