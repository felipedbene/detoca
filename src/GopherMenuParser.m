//
//  GopherMenuParser.m
//  DeToca
//

#import "GopherMenuParser.h"
#import "GopherItem.h"

@implementation GopherMenuParser

+ (NSString *)stringFromData:(NSData *)data
{
    if (data == nil) {
        return @"";
    }
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (s == nil) {
        // Many legacy Gopher servers are Latin-1 or raw high-bit bytes.
        // ISO Latin-1 never fails to decode, so this is a safe fallback.
        s = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    }
    if (s == nil) {
        s = [[NSString alloc] initWithString:@""];
    }
    return [s autorelease];
}

+ (NSArray *)parseMenuData:(NSData *)data
{
    return [self parseMenu:[self stringFromData:data]];
}

+ (NSArray *)parseMenu:(NSString *)text
{
    NSMutableArray *items = [NSMutableArray array];
    if (text == nil) {
        return items;
    }

    // Split on LF; strip a trailing CR from each line so CRLF and bare LF are
    // both handled. Do not use -componentsSeparatedByCharactersInSet: because
    // that would collapse CRLF into an empty line between CR and LF.
    NSArray *lines = [text componentsSeparatedByString:@"\n"];
    NSUInteger i, count = [lines count];
    for (i = 0; i < count; i++) {
        NSString *line = [lines objectAtIndex:i];
        if ([line hasSuffix:@"\r"]) {
            line = [line substringToIndex:[line length] - 1];
        }

        // A lone "." on its own line terminates the menu (RFC 1436).
        if ([line isEqualToString:@"."]) {
            break;
        }
        // Skip genuinely empty lines (the final split fragment after a
        // trailing newline is one such). Empty info lines are represented in
        // gophermaps as "i" with nothing after, which is length >= 1 here.
        if ([line length] == 0) {
            continue;
        }

        unichar type = [line characterAtIndex:0];
        NSString *rest = [line substringFromIndex:1];

        // Tab-split the remainder into: display, selector, host, port.
        NSArray *fields = [rest componentsSeparatedByString:@"\t"];
        NSUInteger nf = [fields count];

        NSString *display  = (nf > 0) ? [fields objectAtIndex:0] : @"";
        NSString *selector = (nf > 1) ? [fields objectAtIndex:1] : @"";
        NSString *host     = (nf > 2) ? [fields objectAtIndex:2] : @"";
        NSString *portStr  = (nf > 3) ? [fields objectAtIndex:3] : @"";

        NSInteger port = 70;
        if ([portStr length] > 0) {
            port = [portStr integerValue];
            if (port <= 0) {
                port = 70;
            }
        }

        GopherItem *item = [GopherItem itemWithType:type
                                            display:display
                                           selector:selector
                                               host:host
                                               port:port];
        [items addObject:item];
    }

    return items;
}

@end
