//
//  DTPlaylistWindowController.h
//  DeToca — fio 9, rebuilt fio 10
//
//  The playlist window, now organized in modes via a segmented control:
//    • Busca — search the /spot/api/1 machine API (no more human-menu parsing);
//      each result plays or enqueues (queue/add) and shows a 64 px thumbnail.
//    • Fila  — the live "up next" queue with 64 px thumbnails, refreshed off the
//      player's existing /now poll (DTPlayerNowChangedNotification), never a new
//      timer; empty queue shows the automatic-radio state.
//    • Playlists — added in fio 10/4 (list + play-by-context).
//
//  Rows draw through DTTrackCell; thumbnails come from the shared cover cache.
//

#import <Cocoa/Cocoa.h>

@class DTSpotAPI;
@class DTCoverCache;

@interface DTPlaylistWindowController : NSObject
    <NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate> {
    NSPanel            *_panel;
    DTSpotAPI          *_api;
    DTCoverCache       *_coverCache;

    NSSegmentedControl *_modeControl;
    NSTextField        *_searchField;
    NSScrollView       *_scroll;
    NSTableView        *_table;
    NSButton           *_playButton;      // Tocar (Busca)
    NSButton           *_enqueueButton;   // Enfileirar (Busca)
    NSTextField        *_statusLabel;     // transient feedback (bottom)
    NSTextField        *_emptyLabel;      // centered "automatic radio" empty state

    NSMutableArray     *_searchRows;      // of NSMutableDictionary {track,artist,uri,albumId,image}
    NSMutableArray     *_queueRows;       // same shape, no uri action
    NSInteger           _mode;            // DTPlaylistModeSearch | DTPlaylistModeQueue
    NSUInteger          _searchGen;       // drops stale search responses
    BOOL                _queueLoaded;     // fetched at least once this session
}

- (void)show;

@end
