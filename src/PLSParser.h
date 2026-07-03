//
//  PLSParser.h
//  DeToca — fio 5
//
//  Extracts the first stream URL from a playlist. Handles PLS
//  ("File1=http://…") and Extended/plain M3U (bare "http://…" lines). gopher-spot
//  serves its stream behind a PLS (the type-`s` "Reabrir stream" item →
//  /spot/stream.pls). Pure Foundation, unit-testable.
//

#import <Foundation/Foundation.h>

@interface PLSParser : NSObject

// The first playable URL in the playlist text, or nil if none is found.
+ (NSString *)firstURLFromPlaylistText:(NSString *)text;

@end
