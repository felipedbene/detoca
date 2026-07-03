//
//  DTSnapshotGuard.h
//  DeToca — fio 10
//
//  Monotonic-ts guard for /now snapshots. gopher-spot runs two replicas, each
//  with a ~1 s micro-cache of /now, behind a load balancer: consecutive polls
//  can land on different pods and return a `ts` slightly out of order. This guard
//  drops any snapshot whose `ts` regressed relative to one already applied, so the
//  seek bar never jumps backwards at the user. Pure Foundation — unit-testable.
//

#import <Foundation/Foundation.h>

@interface DTSnapshotGuard : NSObject {
    long long _lastTs;   // highest ts accepted so far (high-water mark)
}

// YES if `ts` may be applied (>= the highest ts seen), advancing the high-water
// mark; NO if it regressed (older than one already shown). A non-positive ts
// (unknown / absent) is always accepted and never moves the mark. An equal ts
// (the micro-cache returning the same document) is accepted — it is idempotent.
- (BOOL)acceptTs:(long long)ts;

// Forget the high-water mark (e.g. when reconnecting to a different backend).
- (void)reset;

@end
