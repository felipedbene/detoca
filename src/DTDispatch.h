//
//  DTDispatch.h
//  DeToca
//
//  Thin async wrapper. The whole app's use of libdispatch (GCD) funnels
//  through these two functions so that the fio-3 10.5 build can swap in an
//  NSThread / NSOperationQueue implementation without touching call sites.
//
//  10.6-only: libdispatch. Isolated here on purpose (see fio-1 API-compat rule).
//

#import <Foundation/Foundation.h>

// Run a block on a background (concurrent) queue.
void DTAsyncBackground(void (^block)(void));

// Run a block on the main thread/queue.
void DTAsyncMain(void (^block)(void));
