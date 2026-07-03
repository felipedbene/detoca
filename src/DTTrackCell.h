//
//  DTTrackCell.h
//  DeToca — fio 10
//
//  A cell-based NSTableView row for a track: a 64 px album thumbnail on the left,
//  the track name over the artist on the right, in the DTTheme dark skin. Snow
//  Leopard has no view-based tables (10.7+), so this draws by hand. Its
//  objectValue is an NSDictionary { track, artist, image } — the controller fills
//  `image` in asynchronously from the cover cache and redraws the row.
//

#import <Cocoa/Cocoa.h>

@interface DTTrackCell : NSCell
@end
