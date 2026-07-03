//
//  main.m
//  DeToca
//
//  Programmatic startup — no NIB. Creates the application, installs the
//  AppDelegate (which builds the menu bar and opens the home window), and runs.
//

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSApplication *app = [NSApplication sharedApplication];
    // Regular app with a Dock icon and menu bar.
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];

    AppDelegate *delegate = [[AppDelegate alloc] init];
    [app setDelegate:delegate];

    // Optional launch location: any argument that looks like a gopher URL.
    // e.g. open DeToca.app --args gopher://gopher.debene.dev/0/map.ansi
    int i;
    for (i = 1; i < argc; i++) {
        NSString *arg = [NSString stringWithUTF8String:argv[i]];
        if ([arg hasPrefix:@"gopher://"] || [arg rangeOfString:@"://"].location != NSNotFound) {
            [delegate setInitialURLString:arg];
            break;
        }
    }

    [app run];

    [delegate release];
    [pool drain];
    return 0;
}
