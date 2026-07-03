//
//  PlayQueue.h
//  DeToca
//
//  Ordered list of PlayQueueItems with a current position and next/prev/replace
//  operations. Pure Foundation — no AppKit, no QTKit — so it is unit-testable.
//

#import <Foundation/Foundation.h>

@class PlayQueueItem;

@interface PlayQueue : NSObject {
    NSArray  *_items;
    NSInteger _currentIndex;   // -1 when empty
}

// Create a queue from PlayQueueItems, starting at startIndex (clamped into
// range; -1 if the list is empty).
- (id)initWithItems:(NSArray *)items startIndex:(NSInteger)startIndex;

- (NSUInteger)count;
- (NSInteger)currentIndex;
- (PlayQueueItem *)currentItem;      // nil when empty

- (BOOL)hasNext;
- (BOOL)hasPrevious;

// Move to the next/previous item and return it, or nil (leaving the index
// unchanged) if there is none. End-of-queue therefore parks on the last item.
- (PlayQueueItem *)advanceToNext;
- (PlayQueueItem *)goToPrevious;

// Replace the contents wholesale (used when a click in another window starts a
// new queue).
- (void)replaceWithItems:(NSArray *)items startIndex:(NSInteger)startIndex;

// "3 / 12" (1-based), or @"" when empty.
- (NSString *)positionString;

@end
