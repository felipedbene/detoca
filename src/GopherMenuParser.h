//
//  GopherMenuParser.h
//  DeToca
//
//  Parses a raw Gopher menu (a directory listing / "gophermap") into an
//  array of GopherItem objects. Pure Foundation, no AppKit.
//
//  Line format (RFC 1436):
//      Tdisplay<TAB>selector<TAB>host<TAB>port<CR><LF>
//  where T is the single type character prepended to the display string.
//  A line consisting solely of "." terminates the menu.
//

#import <Foundation/Foundation.h>

@class GopherItem;

@interface GopherMenuParser : NSObject

// Parse menu text into an array of GopherItem. Tolerant of malformed lines:
// missing tab-separated fields default to empty strings / port 70, and lines
// with no tabs are treated as bare display text (typically 'i' info lines).
// Handles CRLF and bare-LF line endings. Stops at a "." terminator line.
+ (NSArray *)parseMenu:(NSString *)text;

// Convenience: decode NSData as UTF-8, falling back to ISO Latin-1 (many
// older Gopher servers emit Latin-1 or raw bytes), then parse.
+ (NSArray *)parseMenuData:(NSData *)data;

// Decode NSData the same way -parseMenuData: does, without parsing. Used by
// the text renderer so menus and text documents share one decoding policy.
+ (NSString *)stringFromData:(NSData *)data;

@end
