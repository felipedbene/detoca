//
//  DTCoverCache.h
//  DeToca — fio 10
//
//  Two-level cache of album cover JPEG bytes: an in-memory NSCache plus a disk
//  cache under ~/Library/Caches/dev.debene.detoca/covers/<album_id>-<size>.jpg.
//  Covers are immutable per (album_id, size), so nothing ever expires — the disk
//  store is only bounded by an LRU size cap. The network fetch is injected (a
//  `fetcher` block) so this class stays pure Foundation and unit-testable: it
//  hands back JPEG NSData, and the UI layer turns that into an NSImage.
//
//  All work happens off the main thread; the handler is delivered on the main
//  thread. The Radinho asks for a 300 cover on album change and the playlist asks
//  for many 64 thumbnails — both are served from cache after the first miss.
//

#import <Foundation/Foundation.h>

// Fetch raw JPEG bytes for (albumId, size) from the backend. `done` MUST be
// called exactly once (with nil on failure). May run on any thread.
typedef void (^DTCoverFetcher)(NSString *albumId, NSInteger size,
                               void (^done)(NSData *jpeg));

@interface DTCoverCache : NSObject {
    NSCache        *_memory;
    NSString       *_diskDir;
    DTCoverFetcher  _fetcher;      // copied
    unsigned long long _maxDiskBytes;
}

@property (nonatomic, copy) DTCoverFetcher fetcher;

// Default cache dir (~/Library/Caches/<bundle id>/covers).
- (id)init;
// Explicit dir (tests point this at a temp directory).
- (id)initWithDirectory:(NSString *)dir;

// Look up the cover for (albumId, size). Serves from memory, then disk, then the
// injected fetcher (storing the result to memory + disk). `handler` fires on the
// main thread with the JPEG bytes, or nil if unavailable. A nil/empty albumId
// yields nil without a fetch.
- (void)coverForAlbum:(NSString *)albumId
                 size:(NSInteger)size
              handler:(void (^)(NSData *jpeg))handler;

// The in-memory / on-disk file name for a key: "<album_id>-<size>.jpg". Pure.
+ (NSString *)fileNameForAlbum:(NSString *)albumId size:(NSInteger)size;
// The absolute disk path for (albumId, size) in this cache's directory.
- (NSString *)diskPathForAlbum:(NSString *)albumId size:(NSInteger)size;

@end
