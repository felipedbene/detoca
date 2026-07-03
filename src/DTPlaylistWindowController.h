//
//  DTPlaylistWindowController.h
//  DeToca — fio 9
//
//  The WinAmp-style playlist window: a clean search that returns a flat, playable
//  track list — no drilling through gopher menus. Search goes to /spot/search
//  (parsed with GopherMenuParser); a result track's selector is /spot/track/<id>,
//  from which we derive the direct play action /spot/play?uri=spotify:track:<id>.
//  Activating a row fires that action; the player window reflects it on its next
//  /now poll.
//
//  Real "up next" queue contents aren't in the v1 API (only queue_len) — that
//  arrives with fio S2; until then this window shows search results.
//

#import <Cocoa/Cocoa.h>
#import "GopherRequest.h"

@interface DTPlaylistWindowController : NSObject
    <NSWindowDelegate, GopherRequestDelegate, NSTableViewDataSource, NSTableViewDelegate> {
    NSPanel        *_panel;
    NSTextField    *_searchField;
    NSTableView    *_table;
    NSMutableArray *_tracks;       // of NSDictionary {title, play}
    GopherRequest  *_searchReq;
    NSInteger       _playingRow;   // last-activated row, or -1
}

- (void)show;

@end
