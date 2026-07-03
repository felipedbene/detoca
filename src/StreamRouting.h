//
//  StreamRouting.h
//  DeToca
//
//  Classifies a URL string as an in-app playable audio stream. Pure Foundation
//  — no AppKit, no QTKit, no gopher — so it is unit-testable and reusable by
//  both the link-handling path and the M3U export.
//

#import <Foundation/Foundation.h>

@interface StreamRouting : NSObject

// YES if the URL is http/https and its path (query string and fragment
// stripped) ends in ".mp3", case-insensitively. Non-http schemes are always NO.
+ (BOOL)isPlayableStreamURLString:(NSString *)urlString;

@end
