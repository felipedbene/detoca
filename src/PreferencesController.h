//
//  PreferencesController.h
//  DeToca
//
//  A minimal Preferences window: shows the resolved document font (so a
//  Cascadia-Code-missing situation is diagnosable) and lets the user pick a
//  different font via the standard font panel.
//

#import <Cocoa/Cocoa.h>

@interface PreferencesController : NSWindowController {
    NSTextField *_fontField;
}

// Build (once) and show the Preferences window.
- (void)showPreferences;

@end
