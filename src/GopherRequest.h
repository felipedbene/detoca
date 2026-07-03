//
//  GopherRequest.h
//  DeToca
//
//  One RFC 1436 transaction: connect to host:port, send "selector\r\n"
//  (a type-7 query is passed as "selector\tquery"), read the whole response
//  to EOF. Runs on a background queue; delegate callbacks fire on the main
//  thread. Cancellable and safe to release while in flight.
//

#import <Foundation/Foundation.h>

@class GopherRequest;

@protocol GopherRequestDelegate <NSObject>
- (void)gopherRequest:(GopherRequest *)request didReceiveData:(NSData *)data;
- (void)gopherRequest:(GopherRequest *)request didFailWithError:(NSError *)error;
@end

extern NSString * const DTGopherErrorDomain;

@interface GopherRequest : NSObject {
    NSString *_host;
    NSInteger _port;
    NSString *_selector;
    id <GopherRequestDelegate> _delegate;   // not retained
    BOOL _cancelled;
    BOOL _running;
}

@property (nonatomic, copy)   NSString *host;
@property (nonatomic, assign) NSInteger port;
@property (nonatomic, copy)   NSString *selector;    // may contain a \t query
@property (nonatomic, assign) id <GopherRequestDelegate> delegate;

+ (id)requestWithHost:(NSString *)host
                 port:(NSInteger)port
             selector:(NSString *)selector;

// Begin fetching. The receiver retains itself until the transaction ends, so
// callers may release their reference immediately after -start.
- (void)start;

// Prevent any further delegate callbacks. Safe to call from -dealloc.
- (void)cancel;

@end
