//
//  DTInputSheet.h
//  DeToca
//
//  A one-field input sheet (NSAlert + accessory text field) with a block
//  completion, wrapping the 10.6 begin/didEnd sheet API. Used for the type-7
//  search prompt and Open Location. The instance retains itself for the
//  lifetime of the sheet.
//

#import <Cocoa/Cocoa.h>

@interface DTInputSheet : NSObject {
    NSAlert     *_alert;
    NSTextField *_field;
    void (^_completion)(NSString *value);  // value == nil means cancelled
}

// Present a prompt on window. The completion is called with the entered text,
// or nil if the user cancelled.
+ (void)promptOnWindow:(NSWindow *)window
                 title:(NSString *)title
               message:(NSString *)message
          defaultValue:(NSString *)defaultValue
           placeholder:(NSString *)placeholder
            completion:(void (^)(NSString *value))completion;

@end
