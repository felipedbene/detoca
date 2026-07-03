//
//  StreamRouting.m
//  DeToca
//

#import "StreamRouting.h"

@implementation StreamRouting

+ (BOOL)isPlayableStreamURLString:(NSString *)urlString
{
    if (urlString == nil) {
        return NO;
    }

    NSString *low = [urlString lowercaseString];
    if (!([low hasPrefix:@"http://"] || [low hasPrefix:@"https://"])) {
        return NO;
    }

    // Drop the query string and fragment before checking the extension, so
    // e.g. "http://host/track.mp3?token=abc#t=10" still qualifies.
    NSRange q = [low rangeOfString:@"?"];
    if (q.location != NSNotFound) {
        low = [low substringToIndex:q.location];
    }
    NSRange h = [low rangeOfString:@"#"];
    if (h.location != NSNotFound) {
        low = [low substringToIndex:h.location];
    }

    return [low hasSuffix:@".mp3"];
}

@end
