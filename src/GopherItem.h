//
//  GopherItem.h
//  DeToca
//
//  One parsed line of a Gopher menu (a "gophermap" line), per RFC 1436.
//  Pure Foundation: this type is used by the parser layer and must not
//  depend on AppKit.
//

#import <Foundation/Foundation.h>

// Broad classification of a Gopher item, derived from its RFC 1436 type
// character. Used by the UI to decide rendering and clickability without
// re-switching on the raw character everywhere.
typedef enum {
    GopherItemKindText = 0,     // '0' text file
    GopherItemKindMenu,         // '1' directory / submenu
    GopherItemKindSearch,       // '7' full-text search server
    GopherItemKindInfo,         // 'i' informational line (non-clickable)
    GopherItemKindHTML,         // 'h' HTML / URL: link (opened externally)
    GopherItemKindSound,        // 's' sound / audio stream (played in the radinho)
    GopherItemKindError,        // '3' error
    GopherItemKindUnknown       // anything else (dimmed, non-clickable)
} GopherItemKind;

@interface GopherItem : NSObject {
    unichar         _type;          // raw RFC 1436 type character
    NSString       *_displayString; // user-visible label
    NSString       *_selector;      // selector string sent to the server
    NSString       *_host;          // hostname
    NSInteger       _port;          // TCP port
}

@property (nonatomic, assign)   unichar    type;
@property (nonatomic, copy)     NSString  *displayString;
@property (nonatomic, copy)     NSString  *selector;
@property (nonatomic, copy)     NSString  *host;
@property (nonatomic, assign)   NSInteger  port;

+ (id)itemWithType:(unichar)type
            display:(NSString *)display
           selector:(NSString *)selector
               host:(NSString *)host
               port:(NSInteger)port;

// Classification derived from -type.
- (GopherItemKind)kind;

// Whether activating this item does anything (fetch or open externally).
- (BOOL)isClickable;

// For 'h' items whose selector is of the form "URL:...", the extracted URL
// string; nil otherwise.
- (NSString *)externalURLString;

@end
