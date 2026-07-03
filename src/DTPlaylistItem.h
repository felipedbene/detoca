//
//  DTPlaylistItem.h
//  DeToca — fio 10
//
//  One entry of /spot/api/1/playlists — the user's playlists as an indexed list
//  (`item.<i>.{id,name,tracks_len}`). We list + play playlists by context; we do
//  NOT read their tracks (Spotify 403s playlist track reads in dev-mode, so
//  tracks_len is typically 0). Pure Foundation — no gopher, no AppKit.
//

#import <Foundation/Foundation.h>

@interface DTPlaylistItem : NSObject {
    NSString *_playlistId;   // playlist id — feed to /spot/play?context_uri=spotify:playlist:<id>
    NSString *_name;         // display name
    NSInteger _tracksLen;    // Spotify's track count (often 0 under the dev-mode block)
}

@property (nonatomic, copy)   NSString *playlistId;
@property (nonatomic, copy)   NSString *name;
@property (nonatomic, assign) NSInteger tracksLen;

// The context uri to start playback of this playlist (spotify:playlist:<id>).
- (NSString *)contextURI;

// Parse the ordered `item.<i>.{id,name,tracks_len}` block from an already-split
// fields dict. Scans i = 0, 1, 2, … stopping at the first index with no
// `item.<i>.id`. Playlists with no id are absent server-side. Never returns nil.
+ (NSArray *)itemsFromFields:(NSDictionary *)fields;
+ (NSArray *)itemsFromResponse:(NSString *)body;

@end
