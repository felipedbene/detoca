//
//  DTPlaylistItem.m
//  DeToca — fio 10
//

#import "DTPlaylistItem.h"
#import "DTNowSnapshot.h"   // +fieldsFromResponse:

@implementation DTPlaylistItem

@synthesize playlistId = _playlistId;
@synthesize name = _name;
@synthesize tracksLen = _tracksLen;

- (void)dealloc
{
    [_playlistId release];
    [_name release];
    [super dealloc];
}

- (NSString *)contextURI
{
    if ([_playlistId length] == 0) {
        return nil;
    }
    return [@"spotify:playlist:" stringByAppendingString:_playlistId];
}

+ (NSArray *)itemsFromFields:(NSDictionary *)fields
{
    NSMutableArray *items = [NSMutableArray array];
    NSUInteger i = 0;
    for (;;) {
        NSString *pid = [fields objectForKey:
                         [NSString stringWithFormat:@"item.%lu.id", (unsigned long)i]];
        if (pid == nil) {
            break;
        }
        DTPlaylistItem *it = [[[DTPlaylistItem alloc] init] autorelease];
        it.playlistId = pid;
        it.name = [fields objectForKey:
                   [NSString stringWithFormat:@"item.%lu.name", (unsigned long)i]];
        it.tracksLen = [[fields objectForKey:
                         [NSString stringWithFormat:@"item.%lu.tracks_len", (unsigned long)i]]
                        integerValue];
        [items addObject:it];
        i++;
    }
    return items;
}

+ (NSArray *)itemsFromResponse:(NSString *)body
{
    return [self itemsFromFields:[DTNowSnapshot fieldsFromResponse:body]];
}

@end
