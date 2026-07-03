//
//  DTSpotAPI.m
//  DeToca — fio 9
//

#import "DTSpotAPI.h"
#import "DTNowSnapshot.h"
#import "DTServerPrefs.h"
#import "GopherRequest.h"

static NSString * const DTSpotAPIBase = @"/spot/api/1";

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

// Adapts a GopherRequest (delegate-based) to a DTNowHandler block, and keeps
// itself alive for the duration of the transaction (the request's delegate is
// not retained). Parses the response into a snapshot or an API error.
@interface DTSpotAPICall : NSObject <GopherRequestDelegate> {
    DTNowHandler   _handler;   // copied
    GopherRequest *_request;   // retained
}
- (id)initWithHandler:(DTNowHandler)handler;
- (void)startHost:(NSString *)host port:(NSInteger)port selector:(NSString *)selector;
@end

@implementation DTSpotAPICall

- (id)initWithHandler:(DTNowHandler)handler
{
    self = [super init];
    if (self != nil) {
        _handler = [handler copy];
    }
    return self;
}

- (void)dealloc
{
    [_handler release];
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

- (void)finishWithSnapshot:(DTNowSnapshot *)snapshot error:(DTSpotAPIError *)error
{
    if (_handler != nil) {
        _handler(snapshot, error);
    }
    [_request setDelegate:nil];
    [self autorelease];   // balances -startHost:port:selector:
}

- (void)gopherRequest:(GopherRequest *)request didReceiveData:(NSData *)data
{
    NSString *body = [[[NSString alloc] initWithData:data
                                            encoding:NSUTF8StringEncoding] autorelease];
    if (body == nil) {
        [self finishWithSnapshot:nil
                           error:[DTSpotAPIError errorWithCode:@"transport"
                                                       message:@"response was not valid UTF-8"]];
        return;
    }

    NSDictionary *fields = [DTNowSnapshot fieldsFromResponse:body];
    NSString *errCode = [fields objectForKey:@"error"];
    if ([errCode length] > 0) {
        [self finishWithSnapshot:nil
                           error:[DTSpotAPIError errorWithCode:errCode
                                                       message:[fields objectForKey:@"message"]]];
        return;
    }

    [self finishWithSnapshot:[DTNowSnapshot snapshotFromResponse:body] error:nil];
}

- (void)gopherRequest:(GopherRequest *)request didFailWithError:(NSError *)error
{
    NSString *msg = [error localizedDescription];
    [self finishWithSnapshot:nil
                       error:[DTSpotAPIError errorWithCode:@"transport"
                                                   message:([msg length] ? msg : @"connection failed")]];
}

@end

#pragma mark - DTSpotAPI

@implementation DTSpotAPI

- (void)callSelector:(NSString *)selector handler:(DTNowHandler)handler
{
    NSString *host = [DTServerPrefs host];
    NSInteger port = [DTServerPrefs port];
    DTSpotAPICall *call = [[DTSpotAPICall alloc] initWithHandler:handler];
    [call startHost:host port:port selector:selector];
    [call release];   // the call self-retains for the transaction's lifetime
}

- (void)fetchNow:(DTNowHandler)handler
{
    [self callSelector:[DTSpotAPIBase stringByAppendingString:@"/now"] handler:handler];
}

- (void)play:(DTNowHandler)handler
{
    [self callSelector:[DTSpotAPIBase stringByAppendingString:@"/play"] handler:handler];
}

- (void)pause:(DTNowHandler)handler
{
    [self callSelector:[DTSpotAPIBase stringByAppendingString:@"/pause"] handler:handler];
}

- (void)next:(DTNowHandler)handler
{
    [self callSelector:[DTSpotAPIBase stringByAppendingString:@"/next"] handler:handler];
}

- (void)previous:(DTNowHandler)handler
{
    [self callSelector:[DTSpotAPIBase stringByAppendingString:@"/prev"] handler:handler];
}

- (void)setVolume:(NSInteger)percent handler:(DTNowHandler)handler
{
    NSString *sel = [NSString stringWithFormat:@"%@/volume?%ld", DTSpotAPIBase, (long)percent];
    [self callSelector:sel handler:handler];
}

- (void)seekTo:(long long)positionMs handler:(DTNowHandler)handler
{
    NSString *sel = [NSString stringWithFormat:@"%@/seek?%lld", DTSpotAPIBase, positionMs];
    [self callSelector:sel handler:handler];
}

@end
