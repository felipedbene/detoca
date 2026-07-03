//
//  GopherItem.m
//  DeToca
//

#import "GopherItem.h"

@implementation GopherItem

@synthesize type = _type;
@synthesize displayString = _displayString;
@synthesize selector = _selector;
@synthesize host = _host;
@synthesize port = _port;

+ (id)itemWithType:(unichar)type
            display:(NSString *)display
           selector:(NSString *)selector
               host:(NSString *)host
               port:(NSInteger)port
{
    GopherItem *item = [[[self alloc] init] autorelease];
    [item setType:type];
    [item setDisplayString:display];
    [item setSelector:selector];
    [item setHost:host];
    [item setPort:port];
    return item;
}

- (void)dealloc
{
    [_displayString release];
    [_selector release];
    [_host release];
    [super dealloc];
}

- (GopherItemKind)kind
{
    switch (_type) {
        case '0': return GopherItemKindText;
        case '1': return GopherItemKindMenu;
        case '7': return GopherItemKindSearch;
        case 'i': return GopherItemKindInfo;
        case 'h': return GopherItemKindHTML;
        case '3': return GopherItemKindError;
        default:  return GopherItemKindUnknown;
    }
}

- (BOOL)isClickable
{
    switch ([self kind]) {
        case GopherItemKindText:
        case GopherItemKindMenu:
        case GopherItemKindSearch:
            return YES;
        case GopherItemKindHTML:
            // Only clickable if we can extract a usable URL.
            return ([self externalURLString] != nil);
        case GopherItemKindInfo:
        case GopherItemKindError:
        case GopherItemKindUnknown:
        default:
            return NO;
    }
}

- (NSString *)externalURLString
{
    if (_selector == nil) {
        return nil;
    }
    // Canonical Gopher form for HTML links: selector is "URL:<real-url>".
    if ([_selector hasPrefix:@"URL:"]) {
        NSString *url = [_selector substringFromIndex:4];
        if ([url length] > 0) {
            return url;
        }
        return nil;
    }
    return nil;
}

@end
