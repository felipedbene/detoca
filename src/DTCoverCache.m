//
//  DTCoverCache.m
//  DeToca — fio 10
//

#import "DTCoverCache.h"
#import "DTDispatch.h"

@interface DTCoverCache ()
- (void)writeCover:(NSData *)jpeg toPath:(NSString *)path;
- (void)pruneDiskToCap;
@end

@implementation DTCoverCache

@synthesize fetcher = _fetcher;

- (id)initWithDirectory:(NSString *)dir
{
    self = [super init];
    if (self != nil) {
        _memory = [[NSCache alloc] init];
        [_memory setName:@"dev.debene.detoca.covers"];
        _diskDir = [dir copy];
        _maxDiskBytes = 32ULL * 1024 * 1024;   // 32 MB LRU cap on disk
    }
    return self;
}

- (id)init
{
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                        NSUserDomainMask, YES);
    NSString *base = ([dirs count] > 0) ? [dirs objectAtIndex:0] : NSTemporaryDirectory();
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
    if ([bid length] == 0) {
        bid = @"dev.debene.detoca";
    }
    NSString *dir = [[base stringByAppendingPathComponent:bid]
                     stringByAppendingPathComponent:@"covers"];
    return [self initWithDirectory:dir];
}

- (void)dealloc
{
    [_memory release];
    [_diskDir release];
    [_fetcher release];
    [super dealloc];
}

#pragma mark - Keys / paths (pure)

+ (NSString *)fileNameForAlbum:(NSString *)albumId size:(NSInteger)size
{
    // Album ids are base62, but be defensive against path separators.
    NSString *safe = [albumId stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    safe = [safe stringByReplacingOccurrencesOfString:@":" withString:@"_"];
    return [NSString stringWithFormat:@"%@-%ld.jpg", safe, (long)size];
}

- (NSString *)diskPathForAlbum:(NSString *)albumId size:(NSInteger)size
{
    return [_diskDir stringByAppendingPathComponent:
            [DTCoverCache fileNameForAlbum:albumId size:size]];
}

#pragma mark - Lookup

- (void)coverForAlbum:(NSString *)albumId
                 size:(NSInteger)size
              handler:(void (^)(NSData *jpeg))handler
{
    if ([albumId length] == 0) {
        if (handler) {
            handler(nil);
        }
        return;
    }

    NSString *key = [DTCoverCache fileNameForAlbum:albumId size:size];
    NSData *mem = [_memory objectForKey:key];
    if (mem != nil) {
        if (handler) {
            handler(mem);   // memory hit: deliver inline (already on main)
        }
        return;
    }

    void (^h)(NSData *) = [handler copy];   // survive the thread hop
    NSString *diskPath = [self diskPathForAlbum:albumId size:size];
    DTCoverFetcher fetch = _fetcher;
    NSCache *memory = _memory;
    DTCoverCache *me = self;

    DTAsyncBackground(^{
        NSData *disk = [NSData dataWithContentsOfFile:diskPath];
        if ([disk length] > 0) {
            [memory setObject:disk forKey:key cost:[disk length]];
            DTAsyncMain(^{ if (h) { h(disk); } [h release]; });
            return;
        }
        if (fetch == nil) {
            DTAsyncMain(^{ if (h) { h(nil); } [h release]; });
            return;
        }
        fetch(albumId, size, ^(NSData *jpeg) {
            if ([jpeg length] > 0) {
                [memory setObject:jpeg forKey:key cost:[jpeg length]];
                NSData *toWrite = [jpeg retain];
                DTAsyncBackground(^{
                    [me writeCover:toWrite toPath:diskPath];
                    [toWrite release];
                });
            }
            NSData *result = ([jpeg length] > 0) ? jpeg : nil;
            DTAsyncMain(^{ if (h) { h(result); } [h release]; });
        });
    });
}

#pragma mark - Disk store

- (void)writeCover:(NSData *)jpeg toPath:(NSString *)path
{
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:_diskDir
  withIntermediateDirectories:YES
                   attributes:nil
                        error:NULL];
    if ([jpeg writeToFile:path atomically:YES]) {
        [self pruneDiskToCap];
    }
}

// Immutable covers never expire; the only bound is total disk size. When over the
// cap, evict least-recently-modified files until back under it.
- (void)pruneDiskToCap
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *names = [fm contentsOfDirectoryAtPath:_diskDir error:NULL];
    if (names == nil) {
        return;
    }

    NSMutableArray *files = [NSMutableArray array];   // { path, size, mdate }
    unsigned long long total = 0;
    NSUInteger i, n = [names count];
    for (i = 0; i < n; i++) {
        NSString *path = [_diskDir stringByAppendingPathComponent:[names objectAtIndex:i]];
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:NULL];
        if (attrs == nil) {
            continue;
        }
        unsigned long long sz = [attrs fileSize];
        NSDate *md = [attrs fileModificationDate];
        total += sz;
        [files addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                          path, @"path",
                          [NSNumber numberWithUnsignedLongLong:sz], @"size",
                          (md ? md : [NSDate distantPast]), @"mdate", nil]];
    }
    if (total <= _maxDiskBytes) {
        return;
    }

    // Oldest first, delete until under the cap.
    [files sortUsingComparator:^NSComparisonResult(id a, id b) {
        return [[a objectForKey:@"mdate"] compare:[b objectForKey:@"mdate"]];
    }];
    for (i = 0; i < [files count] && total > _maxDiskBytes; i++) {
        NSDictionary *f = [files objectAtIndex:i];
        if ([fm removeItemAtPath:[f objectForKey:@"path"] error:NULL]) {
            total -= [[f objectForKey:@"size"] unsignedLongLongValue];
        }
    }
}

@end
