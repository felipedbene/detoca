//
//  GopherResource.h
//  DeToca
//
//  A resolvable Gopher location: host, port, item type, selector, plus the
//  display string used to title a window. Also parses user-entered locations
//  (Open Location…): gopher:// URLs and bare "host[:port][/type/selector]".
//  Pure Foundation, no AppKit.
//

#import <Foundation/Foundation.h>

@class GopherItem;

@interface GopherResource : NSObject {
    NSString  *_host;
    NSInteger  _port;
    unichar    _type;
    NSString  *_selector;
    NSString  *_displayString;
}

@property (nonatomic, copy)   NSString  *host;
@property (nonatomic, assign) NSInteger  port;
@property (nonatomic, assign) unichar    type;
@property (nonatomic, copy)   NSString  *selector;
@property (nonatomic, copy)   NSString  *displayString;

+ (id)resourceWithHost:(NSString *)host
                  port:(NSInteger)port
                  type:(unichar)type
              selector:(NSString *)selector
               display:(NSString *)display;

// Build a resource from a menu item (carrying the item's display string).
+ (id)resourceWithItem:(GopherItem *)item;

// Parse a user-entered location string. Accepts:
//   gopher://host[:port][/<type><selector>]
//   host[:port][/<type><selector>]
// where the first path character after the leading slash is the item type
// and everything after it (including any further slashes) is the selector.
// With no path, defaults to a type-1 menu with an empty selector.
// Returns nil if no host can be determined.
+ (id)resourceFromLocationString:(NSString *)location;

// "host:port/selector" summary shown as a window subtitle.
- (NSString *)locationSummary;

// Canonical gopher:// URL form.
- (NSString *)urlString;

@end
