//
//  PlayQueueItem.m
//  DeToca
//

#import "PlayQueueItem.h"

@implementation PlayQueueItem

@synthesize title = _title;
@synthesize urlString = _urlString;

+ (id)itemWithTitle:(NSString *)title urlString:(NSString *)urlString
{
    PlayQueueItem *item = [[[self alloc] init] autorelease];
    [item setTitle:title];
    [item setUrlString:urlString];
    return item;
}

- (void)dealloc
{
    [_title release];
    [_urlString release];
    [super dealloc];
}

@end
