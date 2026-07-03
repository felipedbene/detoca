//
//  DTSpotAPI.m
//  DeToca — fio 9, extended fio 10
//

#import "DTSpotAPI.h"
#import "DTNowSnapshot.h"
#import "DTTrackItem.h"
#import "DTPlaylistItem.h"
#import "DTSnapshotGuard.h"
#import "DTServerPrefs.h"
#import "GopherRequest.h"

static NSString * const DTSpotAPIBase = @"/spot/api/1";
static NSString * const DTSpotPlayBase = @"/spot/play";   // the HUMAN play selector

// Percent-encode a query value for a `?q=` argument, escaping the sub-delims and
// space so an arbitrary UTF-8 search string can't break the selector. Colons in a
// spotify: uri are left intact elsewhere (the server expects them literal).
static NSString *DTURLEncode(NSString *s)
{
    if (s == nil) {
        return @"";
    }
    CFStringRef enc = CFURLCreateStringByAddingPercentEscapes(
        NULL, (CFStringRef)s, NULL,
        CFSTR(":/?#[]@!$&'()*+,;= "), kCFStringEncodingUTF8);
    return [(NSString *)enc autorelease];
}

@implementation DTSpotAPIError

@synthesize code = _code;
@synthesize message = _message;

+ (DTSpotAPIError *)errorWithCode:(NSString *)code message:(NSString *)message
{
    DTSpotAPIError *e = [[[DTSpotAPIError alloc] init] autorelease];
    e.code = code;
    e.message = message;
    return e;
}

- (void)dealloc
{
    [_code release];
    [_message release];
    [super dealloc];
}

@end

#pragma mark - One in-flight API call

// Adapts a GopherRequest (delegate-based) to a raw-data completion block, and
// keeps itself alive for the duration of the transaction (the request's delegate
// is not retained). Delivers raw bytes; the caller decides how to parse them.
@interface DTSpotAPICall : NSObject <GopherRequestDelegate> {
    void (^_completion)(NSData *data, DTSpotAPIError *error);   // copied
    GopherRequest *_request;                                    // retained
}
- (id)initWithCompletion:(void (^)(NSData *data, DTSpotAPIError *error))completion;
- (void)startHost:(NSString *)host port:(NSInteger)port selector:(NSString *)selector;
@end

@implementation DTSpotAPICall

- (id)initWithCompletion:(void (^)(NSData *, DTSpotAPIError *))completion
{
    self = [super init];
    if (self != nil) {
        _completion = [completion copy];
    }
    return self;
}

- (void)dealloc
{
    [_completion release];
    [_request release];
    [super dealloc];
}

- (void)startHost:(NSString *)host port:(NSInteger)port selector:(NSString *)selector
{
    _request = [[GopherRequest requestWithHost:host port:port selector:selector] retain];
    [_request setDelegate:self];
    [self retain];        // stay alive until a callback fires (delegate isn't retained)
    [_request start];
}

- (void)finishWithData:(NSData *)data error:(DTSpotAPIError *)error
{
    if (_completion != nil) {
        _completion(data, error);
    }
    [_request setDelegate:nil];
    [self autorelease];   // balances -startHost:port:selector:
}

- (void)gopherRequest:(GopherRequest *)request didReceiveData:(NSData *)data
{
    [self finishWithData:data error:nil];
}

- (void)gopherRequest:(GopherRequest *)request didFailWithError:(NSError *)error
{
    NSString *msg = [error localizedDescription];
    [self finishWithData:nil
                   error:[DTSpotAPIError errorWithCode:@"transport"
                                               message:([msg length] ? msg : @"connection failed")]];
}

@end

#pragma mark - DTSpotAPI

@implementation DTSpotAPI

- (id)init
{
    self = [super init];
    if (self != nil) {
        _guard = [[DTSnapshotGuard alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_guard release];
    [super dealloc];
}

- (void)resetSnapshotGuard
{
    [(DTSnapshotGuard *)_guard reset];
}

#pragma mark - Transport primitives

// Raw fetch: deliver the selector's response bytes (or a transport error).
- (void)fetchSelector:(NSString *)selector
           completion:(void (^)(NSData *data, DTSpotAPIError *error))completion
{
    NSString *host = [DTServerPrefs host];
    NSInteger port = [DTServerPrefs port];
    DTSpotAPICall *call = [[DTSpotAPICall alloc] initWithCompletion:completion];
    [call startHost:host port:port selector:selector];
    [call release];   // the call self-retains for the transaction's lifetime
}

// Text fetch: decode UTF-8, split into fields, surface a v1 `error` as a
// DTSpotAPIError. On success delivers the parsed fields dict.
- (void)fetchTextSelector:(NSString *)selector
               completion:(void (^)(NSDictionary *fields, DTSpotAPIError *error))completion
{
    void (^comp)(NSDictionary *, DTSpotAPIError *) = [[completion copy] autorelease];
    [self fetchSelector:selector completion:^(NSData *data, DTSpotAPIError *error) {
        if (error != nil) {
            comp(nil, error);
            return;
        }
        NSString *body = [[[NSString alloc] initWithData:data
                                                encoding:NSUTF8StringEncoding] autorelease];
        if (body == nil) {
            comp(nil, [DTSpotAPIError errorWithCode:@"transport"
                                            message:@"response was not valid UTF-8"]);
            return;
        }
        NSDictionary *fields = [DTNowSnapshot fieldsFromResponse:body];
        NSString *errCode = [fields objectForKey:@"error"];
        if ([errCode length] > 0) {
            comp(nil, [DTSpotAPIError errorWithCode:errCode
                                            message:[fields objectForKey:@"message"]]);
            return;
        }
        comp(fields, nil);
    }];
}

// Snapshot fetch. `guarded` YES (the poll) drops a ts-regressed snapshot — both
// args nil. Commands pass NO: they always apply (user feedback), but still feed
// the guard's high-water mark so a later stale poll stays blocked.
- (void)fetchSnapshotSelector:(NSString *)selector
                      guarded:(BOOL)guarded
                      handler:(DTNowHandler)handler
{
    DTNowHandler h = [[handler copy] autorelease];
    DTSnapshotGuard *guard = (DTSnapshotGuard *)_guard;
    [self fetchTextSelector:selector completion:^(NSDictionary *fields, DTSpotAPIError *error) {
        if (error != nil) {
            if (h) { h(nil, error); }
            return;
        }
        DTNowSnapshot *snap = [DTNowSnapshot snapshotFromFields:fields];
        BOOL accepted = [guard acceptTs:snap.ts];
        if (guarded && !accepted) {
            if (h) { h(nil, nil); }   // stale replica answered — keep current state
            return;
        }
        if (h) { h(snap, nil); }
    }];
}

- (void)fetchTrackListSelector:(NSString *)selector handler:(DTTrackListHandler)handler
{
    DTTrackListHandler h = [[handler copy] autorelease];
    [self fetchTextSelector:selector completion:^(NSDictionary *fields, DTSpotAPIError *error) {
        if (error != nil) {
            if (h) { h(nil, error); }
            return;
        }
        if (h) { h([DTTrackItem itemsFromFields:fields], nil); }
    }];
}

// Fire a human /spot/play selector (context or single track). The reply is a
// gophermap we discard; success = no transport error. Poll /now for the result.
- (void)firePlaySelector:(NSString *)selector handler:(DTPlainHandler)handler
{
    DTPlainHandler h = [[handler copy] autorelease];
    [self fetchSelector:selector completion:^(NSData *data, DTSpotAPIError *error) {
        if (h) { h(error); }
    }];
}

#pragma mark - State + transport

- (void)fetchNow:(DTNowHandler)handler
{
    [self fetchSnapshotSelector:[DTSpotAPIBase stringByAppendingString:@"/now"]
                        guarded:YES handler:handler];
}

- (void)play:(DTNowHandler)handler
{
    [self fetchSnapshotSelector:[DTSpotAPIBase stringByAppendingString:@"/play"]
                        guarded:NO handler:handler];
}

- (void)pause:(DTNowHandler)handler
{
    [self fetchSnapshotSelector:[DTSpotAPIBase stringByAppendingString:@"/pause"]
                        guarded:NO handler:handler];
}

- (void)next:(DTNowHandler)handler
{
    [self fetchSnapshotSelector:[DTSpotAPIBase stringByAppendingString:@"/next"]
                        guarded:NO handler:handler];
}

- (void)previous:(DTNowHandler)handler
{
    [self fetchSnapshotSelector:[DTSpotAPIBase stringByAppendingString:@"/prev"]
                        guarded:NO handler:handler];
}

- (void)setVolume:(NSInteger)percent handler:(DTNowHandler)handler
{
    NSString *sel = [NSString stringWithFormat:@"%@/volume?%ld", DTSpotAPIBase, (long)percent];
    [self fetchSnapshotSelector:sel guarded:NO handler:handler];
}

- (void)seekTo:(long long)positionMs handler:(DTNowHandler)handler
{
    NSString *sel = [NSString stringWithFormat:@"%@/seek?%lld", DTSpotAPIBase, positionMs];
    [self fetchSnapshotSelector:sel guarded:NO handler:handler];
}

#pragma mark - Queue

- (void)fetchQueue:(DTTrackListHandler)handler
{
    [self fetchTrackListSelector:[DTSpotAPIBase stringByAppendingString:@"/queue"]
                         handler:handler];
}

- (void)queueAddURI:(NSString *)uri handler:(DTTrackListHandler)handler
{
    // The bare uri is the argument after `?` (colons intact); the reply is /queue.
    NSString *sel = [NSString stringWithFormat:@"%@/queue/add?%@", DTSpotAPIBase, uri];
    [self fetchTrackListSelector:sel handler:handler];
}

#pragma mark - Search

- (void)search:(NSString *)query handler:(DTTrackListHandler)handler
{
    NSString *sel = [NSString stringWithFormat:@"%@/search?q=%@",
                     DTSpotAPIBase, DTURLEncode(query)];
    [self fetchTrackListSelector:sel handler:handler];
}

#pragma mark - Playlists (list + play-by-context)

- (void)playlistsAtOffset:(NSInteger)offset handler:(DTPlaylistsHandler)handler
{
    DTPlaylistsHandler h = [[handler copy] autorelease];
    NSString *sel = (offset > 0)
        ? [NSString stringWithFormat:@"%@/playlists?offset=%ld", DTSpotAPIBase, (long)offset]
        : [DTSpotAPIBase stringByAppendingString:@"/playlists"];
    [self fetchTextSelector:sel completion:^(NSDictionary *fields, DTSpotAPIError *error) {
        if (error != nil) {
            if (h) { h(nil, 0, 0, error); }
            return;
        }
        NSArray *items = [DTPlaylistItem itemsFromFields:fields];
        NSInteger total = [[fields objectForKey:@"total"] integerValue];
        NSInteger off = [[fields objectForKey:@"offset"] integerValue];
        if (h) { h(items, total, off, nil); }
    }];
}

- (void)playContextURI:(NSString *)contextURI
                offset:(NSInteger)offset
               handler:(DTPlainHandler)handler
{
    NSString *sel = [NSString stringWithFormat:@"%@?context_uri=%@&offset=%ld",
                     DTSpotPlayBase, contextURI, (long)offset];
    [self firePlaySelector:sel handler:handler];
}

- (void)playTrackURI:(NSString *)trackURI handler:(DTPlainHandler)handler
{
    NSString *sel = [NSString stringWithFormat:@"%@?uri=%@", DTSpotPlayBase, trackURI];
    [self firePlaySelector:sel handler:handler];
}

#pragma mark - Wake

- (void)wake:(DTNowHandler)handler
{
    [self fetchSnapshotSelector:[DTSpotAPIBase stringByAppendingString:@"/wake"]
                        guarded:NO handler:handler];
}

- (void)wakeAndPlay:(DTNowHandler)handler
{
    [self fetchSnapshotSelector:[DTSpotAPIBase stringByAppendingString:@"/wake?play=1"]
                        guarded:NO handler:handler];
}

#pragma mark - Cover bytes

- (void)coverForAlbum:(NSString *)albumId size:(NSInteger)size handler:(DTCoverHandler)handler
{
    DTCoverHandler h = [[handler copy] autorelease];
    NSString *sel = [NSString stringWithFormat:@"%@/cover/%@/%ld",
                     DTSpotAPIBase, albumId, (long)size];
    [self fetchSelector:sel completion:^(NSData *data, DTSpotAPIError *error) {
        if (error != nil) {
            if (h) { h(nil, error); }
            return;
        }
        // The one binary endpoint: a JPEG starts with the SOI marker FF D8. A v1
        // text error (bad_range / not_found) comes back as a `key<TAB>value` body.
        const unsigned char *b = [data bytes];
        if ([data length] >= 2 && b[0] == 0xFF && b[1] == 0xD8) {
            if (h) { h(data, nil); }
            return;
        }
        NSString *body = [[[NSString alloc] initWithData:data
                                                encoding:NSUTF8StringEncoding] autorelease];
        NSDictionary *fields = [DTNowSnapshot fieldsFromResponse:(body ? body : @"")];
        NSString *code = [fields objectForKey:@"error"];
        if ([code length] == 0) {
            code = @"not_found";
        }
        if (h) {
            h(nil, [DTSpotAPIError errorWithCode:code
                                         message:[fields objectForKey:@"message"]]);
        }
    }];
}

@end
