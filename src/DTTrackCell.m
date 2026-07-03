//
//  DTTrackCell.m
//  DeToca — fio 10
//

#import "DTTrackCell.h"
#import "DTTheme.h"

#define DT_THUMB 64.0

@implementation DTTrackCell

- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)controlView
{
    id value = [self objectValue];
    if (![value isKindOfClass:[NSDictionary class]]) {
        return;
    }
    NSDictionary *m = (NSDictionary *)value;

    // Thumbnail on the left, vertically centered.
    NSRect thumb = NSMakeRect(frame.origin.x + 4,
                              frame.origin.y + (frame.size.height - DT_THUMB) / 2.0,
                              DT_THUMB, DT_THUMB);
    NSImage *img = [m objectForKey:@"image"];
    if (img != nil) {
        [img drawInRect:thumb
               fromRect:NSZeroRect
              operation:NSCompositeSourceOver
               fraction:1.0];
    } else {
        // A faint placeholder box keeps the layout stable while the thumb loads.
        [[DTTheme panelInk] set];
        NSRectFill(thumb);
    }

    // Text to the right of the thumbnail.
    CGFloat tx = NSMaxX(thumb) + 8.0;
    CGFloat tw = NSMaxX(frame) - tx - 6.0;
    if (tw < 10.0) {
        return;
    }

    NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [ps setLineBreakMode:NSLineBreakByTruncatingTail];

    NSDictionary *trackAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
        [DTTheme uiFontOfSize:12.0],    NSFontAttributeName,
        [DTTheme textBright],           NSForegroundColorAttributeName,
        ps,                             NSParagraphStyleAttributeName, nil];
    NSDictionary *artistAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
        [DTTheme uiFontOfSize:10.0],    NSFontAttributeName,
        [DTTheme textDim],              NSForegroundColorAttributeName,
        ps,                             NSParagraphStyleAttributeName, nil];

    // The table draws its content flipped (origin top-left), so a larger y is
    // lower on screen: track name sits above the artist.
    NSString *track  = [m objectForKey:@"track"];
    NSString *artist = [m objectForKey:@"artist"];
    NSRect trackRect  = NSMakeRect(tx, frame.origin.y + 14.0, tw, 16.0);
    NSRect artistRect = NSMakeRect(tx, frame.origin.y + 34.0, tw, 14.0);
    [(track  ? track  : @"") drawInRect:trackRect  withAttributes:trackAttrs];
    [(artist ? artist : @"") drawInRect:artistRect withAttributes:artistAttrs];
}

@end
