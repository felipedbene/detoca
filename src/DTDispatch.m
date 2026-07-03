//
//  DTDispatch.m
//  DeToca
//

#import "DTDispatch.h"
#import <dispatch/dispatch.h>   // 10.6-only: libdispatch

void DTAsyncBackground(void (^block)(void))
{
    // 10.6-only: fio 3 replaces this with an NSOperationQueue/NSThread path.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                   block);
}

void DTAsyncMain(void (^block)(void))
{
    // 10.6-only: fio 3 replaces this with -performSelectorOnMainThread:.
    dispatch_async(dispatch_get_main_queue(), block);
}
