//
//  PlayQueue.m
//  DeToca
//

#import "PlayQueue.h"
#import "PlayQueueItem.h"

@implementation PlayQueue

- (id)initWithItems:(NSArray *)items startIndex:(NSInteger)startIndex
{
    self = [super init];
    if (self != nil) {
        [self replaceWithItems:items startIndex:startIndex];
    }
    return self;
}

- (void)dealloc
{
    [_items release];
    [super dealloc];
}

- (void)replaceWithItems:(NSArray *)items startIndex:(NSInteger)startIndex
{
    NSArray *copy = (items != nil) ? [items copy] : [[NSArray alloc] init];
    [_items release];
    _items = copy;

    NSInteger n = (NSInteger)[_items count];
    if (n == 0) {
        _currentIndex = -1;
    } else if (startIndex < 0) {
        _currentIndex = 0;
    } else if (startIndex >= n) {
        _currentIndex = n - 1;
    } else {
        _currentIndex = startIndex;
    }
}

- (NSUInteger)count
{
    return [_items count];
}

- (NSInteger)currentIndex
{
    return _currentIndex;
}

- (PlayQueueItem *)currentItem
{
    if (_currentIndex < 0 || _currentIndex >= (NSInteger)[_items count]) {
        return nil;
    }
    return [_items objectAtIndex:_currentIndex];
}

- (BOOL)hasNext
{
    return (_currentIndex >= 0 && _currentIndex < (NSInteger)[_items count] - 1);
}

- (BOOL)hasPrevious
{
    return (_currentIndex > 0);
}

- (PlayQueueItem *)advanceToNext
{
    if (![self hasNext]) {
        return nil;
    }
    _currentIndex++;
    return [self currentItem];
}

- (PlayQueueItem *)goToPrevious
{
    if (![self hasPrevious]) {
        return nil;
    }
    _currentIndex--;
    return [self currentItem];
}

- (NSString *)positionString
{
    if ([_items count] == 0) {
        return @"";
    }
    return [NSString stringWithFormat:@"%ld / %lu",
            (long)(_currentIndex + 1), (unsigned long)[_items count]];
}

@end
