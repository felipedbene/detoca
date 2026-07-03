//
//  DTInputSheet.m
//  DeToca
//

#import "DTInputSheet.h"

@interface DTInputSheet ()
- (void)alertDidEnd:(NSAlert *)alert
         returnCode:(NSInteger)returnCode
        contextInfo:(void *)contextInfo;
@end

@implementation DTInputSheet

+ (void)promptOnWindow:(NSWindow *)window
                 title:(NSString *)title
               message:(NSString *)message
          defaultValue:(NSString *)defaultValue
           placeholder:(NSString *)placeholder
            completion:(void (^)(NSString *value))completion
{
    DTInputSheet *sheet = [[DTInputSheet alloc] init];
    sheet->_completion = [completion copy];

    sheet->_alert = [[NSAlert alloc] init];
    [sheet->_alert setMessageText:(title ? title : @"")];
    [sheet->_alert setInformativeText:(message ? message : @"")];
    [sheet->_alert addButtonWithTitle:@"OK"];
    [sheet->_alert addButtonWithTitle:@"Cancel"];

    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 320, 24)];
    [[field cell] setPlaceholderString:(placeholder ? placeholder : @"")];
    if (defaultValue != nil) {
        [field setStringValue:defaultValue];
    }
    [sheet->_alert setAccessoryView:field];
    sheet->_field = field;  // retained via the alert's accessory view; keep ref

    if (window != nil) {
        [sheet->_alert beginSheetModalForWindow:window
                                  modalDelegate:sheet
                                 didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                                    contextInfo:NULL];
        // Give the text field first responder so typing works immediately.
        [[sheet->_alert window] makeFirstResponder:field];
    } else {
        NSInteger rc = [sheet->_alert runModal];
        [sheet alertDidEnd:sheet->_alert returnCode:rc contextInfo:NULL];
    }
}

- (void)alertDidEnd:(NSAlert *)alert
         returnCode:(NSInteger)returnCode
        contextInfo:(void *)contextInfo
{
    NSString *value = nil;
    if (returnCode == NSAlertFirstButtonReturn) {
        value = [[[_field stringValue] copy] autorelease];
    }
    if (_completion != NULL) {
        _completion(value);
    }
    // Balance the self-retain established in +promptOnWindow:.
    [self autorelease];
}

- (void)dealloc
{
    [_alert release];
    [_field release];
    [_completion release];  // block copied with -copy; release balances it
    [super dealloc];
}

@end
