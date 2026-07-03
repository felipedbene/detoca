//
//  BookmarkStore.m
//  DeToca
//

#import "BookmarkStore.h"
#import "GopherResource.h"

@implementation BookmarkStore

+ (NSString *)supportDirectory
{
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                        NSUserDomainMask, YES);
    NSString *base = ([dirs count] > 0)
        ? [dirs objectAtIndex:0]
        : [@"~/Library/Application Support" stringByExpandingTildeInPath];
    return [base stringByAppendingPathComponent:@"DeToca"];
}

+ (NSString *)bookmarksPath
{
    return [[self supportDirectory] stringByAppendingPathComponent:@"bookmarks.gophermap"];
}

+ (void)ensureExists
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [self supportDirectory];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir
      withIntermediateDirectories:YES
                       attributes:nil
                            error:NULL];
    }

    NSString *path = [self bookmarksPath];
    if (![fm fileExistsAtPath:path]) {
        // Seed with a header (info lines) and the DeBurrow home bookmark.
        NSString *seed =
            @"iDeToca Bookmarks\tfake\t(NULL)\t0\n"
            @"i(this is a plain gophermap — edit it by hand if you like)\tfake\t(NULL)\t0\n"
            @"i\tfake\t(NULL)\t0\n"
            @"1DeBurrow Home (gopher.debene.dev)\t\tgopher.debene.dev\t70\n";
        [seed writeToFile:path
               atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:NULL];
    }
}

+ (NSString *)bookmarksText
{
    [self ensureExists];
    NSString *text = [NSString stringWithContentsOfFile:[self bookmarksPath]
                                               encoding:NSUTF8StringEncoding
                                                  error:NULL];
    if (text == nil) {
        text = @"iCould not read bookmarks file.\tfake\t(NULL)\t0\n";
    }
    return text;
}

+ (BOOL)addBookmarkForResource:(GopherResource *)resource
{
    if (resource == nil || [[resource host] length] == 0) {
        return NO;
    }
    [self ensureExists];

    NSString *display = [resource displayString];
    if ([display length] == 0) {
        display = [resource host];
    }
    // Strip any tabs/newlines from the display so we don't corrupt the map.
    display = [display stringByReplacingOccurrencesOfString:@"\t" withString:@" "];
    display = [display stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    display = [display stringByReplacingOccurrencesOfString:@"\r" withString:@" "];

    NSString *line = [NSString stringWithFormat:@"%C%@\t%@\t%@\t%ld\n",
                      [resource type], display,
                      ([resource selector] ? [resource selector] : @""),
                      [resource host], (long)[resource port]];

    NSString *path = [self bookmarksPath];
    NSString *current = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:NULL];
    if (current == nil) {
        current = @"";
    }
    // Ensure the file ends with a newline before appending.
    if ([current length] > 0 && ![current hasSuffix:@"\n"]) {
        current = [current stringByAppendingString:@"\n"];
    }
    NSString *updated = [current stringByAppendingString:line];

    return [updated writeToFile:path
                     atomically:YES
                       encoding:NSUTF8StringEncoding
                          error:NULL];
}

@end
