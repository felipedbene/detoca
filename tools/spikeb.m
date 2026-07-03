//
//  spikeb.m
//  DeToca — Spike B
//
//  Command-line Gopher fetch built on the real GopherRequest networking layer,
//  to lock down the network path before any UI work. Prints the raw response
//  to stdout and a short summary (byte count / first parsed items) to stderr.
//
//  Usage:
//      spikeb [host] [port] [selector]
//  Defaults: gopher.debene.dev 70 (empty selector = root menu)
//
//  Examples:
//      spikeb                                  # debene root
//      spikeb gopher.debene.dev 70 /cta        # a gopher-cta map selector
//

#import <Foundation/Foundation.h>
#import "GopherRequest.h"
#import "GopherMenuParser.h"
#import "GopherItem.h"

@interface SpikeDelegate : NSObject <GopherRequestDelegate> {
    BOOL _done;
    BOOL _ok;
}
@property (nonatomic, assign) BOOL done;
@property (nonatomic, assign) BOOL ok;
@end

@implementation SpikeDelegate
@synthesize done = _done;
@synthesize ok = _ok;

- (void)gopherRequest:(GopherRequest *)request didReceiveData:(NSData *)data
{
    fwrite([data bytes], 1, [data length], stdout);
    fflush(stdout);

    fprintf(stderr, "\n--- spikeb: received %lu bytes ---\n",
            (unsigned long)[data length]);

    // Also show the first few parsed items to confirm the parser agrees.
    NSArray *items = [GopherMenuParser parseMenuData:data];
    fprintf(stderr, "parsed %lu menu item(s)\n", (unsigned long)[items count]);
    NSUInteger i, n = [items count];
    if (n > 8) n = 8;
    for (i = 0; i < n; i++) {
        GopherItem *it = [items objectAtIndex:i];
        fprintf(stderr, "  [%C] %s\n", [it type],
                [[it displayString] UTF8String]);
    }
    _ok = YES;
    _done = YES;
}

- (void)gopherRequest:(GopherRequest *)request didFailWithError:(NSError *)error
{
    fprintf(stderr, "spikeb: ERROR: %s\n", [[error localizedDescription] UTF8String]);
    _ok = NO;
    _done = YES;
}
@end

int main(int argc, const char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSString *host = (argc > 1) ? [NSString stringWithUTF8String:argv[1]] : @"gopher.debene.dev";
    NSInteger port = (argc > 2) ? atoi(argv[2]) : 70;
    NSString *selector = (argc > 3) ? [NSString stringWithUTF8String:argv[3]] : @"";

    fprintf(stderr, "spikeb: fetching %s:%ld selector=\"%s\"\n",
            [host UTF8String], (long)port, [selector UTF8String]);

    SpikeDelegate *delegate = [[[SpikeDelegate alloc] init] autorelease];
    GopherRequest *req = [GopherRequest requestWithHost:host port:port selector:selector];
    [req setDelegate:delegate];
    [req start];

    // Pump the main run loop until the async delegate callback lands.
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:45.0];
    while (![delegate done] && [deadline timeIntervalSinceNow] > 0) {
        NSAutoreleasePool *loopPool = [[NSAutoreleasePool alloc] init];
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        [loopPool drain];
    }

    int status = [delegate ok] ? 0 : 1;
    if (![delegate done]) {
        fprintf(stderr, "spikeb: timed out waiting for response\n");
        status = 2;
    }
    [pool drain];
    return status;
}
