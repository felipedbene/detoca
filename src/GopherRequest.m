//
//  GopherRequest.m
//  DeToca
//

#import "GopherRequest.h"
#import "DTDispatch.h"

#import <sys/socket.h>
#import <sys/time.h>
#import <netdb.h>
#import <netinet/in.h>
#import <unistd.h>
#import <fcntl.h>
#import <errno.h>
#import <string.h>

NSString * const DTGopherErrorDomain = @"DTGopherErrorDomain";

#define DT_CONNECT_TIMEOUT 10   // seconds
#define DT_READ_TIMEOUT    30   // seconds

enum {
    DTGopherErrorResolve   = 1,
    DTGopherErrorConnect   = 2,
    DTGopherErrorTimeout   = 3,
    DTGopherErrorSend      = 4,
    DTGopherErrorRead      = 5
};

static NSError *DTMakeError(NSInteger code, NSString *message)
{
    NSDictionary *info = [NSDictionary dictionaryWithObject:message
                                                     forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:DTGopherErrorDomain code:code userInfo:info];
}

// Connect to a single resolved address with a bounded timeout. Returns the
// connected socket fd, or -1 on failure/timeout. Leaves the socket blocking.
static int DTConnectWithTimeout(struct addrinfo *ai, int timeoutSeconds)
{
    int fd = socket(ai->ai_family, ai->ai_socktype, ai->ai_protocol);
    if (fd < 0) {
        return -1;
    }

    // Avoid SIGPIPE if the peer closes during send.
    int on = 1;
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof(on));

    // Non-blocking connect so we can time it out with select().
    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);

    int rc = connect(fd, ai->ai_addr, ai->ai_addrlen);
    if (rc == 0) {
        fcntl(fd, F_SETFL, flags); // restore blocking
        return fd;
    }
    if (errno != EINPROGRESS) {
        close(fd);
        return -1;
    }

    fd_set wset;
    FD_ZERO(&wset);
    FD_SET(fd, &wset);
    struct timeval tv;
    tv.tv_sec = timeoutSeconds;
    tv.tv_usec = 0;

    rc = select(fd + 1, NULL, &wset, NULL, &tv);
    if (rc <= 0) {
        // 0 == timed out, <0 == error.
        close(fd);
        return -1;
    }

    int soErr = 0;
    socklen_t len = sizeof(soErr);
    if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &soErr, &len) < 0 || soErr != 0) {
        close(fd);
        return -1;
    }

    fcntl(fd, F_SETFL, flags); // restore blocking
    return fd;
}

// Perform the whole transaction synchronously. Returns response bytes, or nil
// with *outError set.
static NSData *DTFetch(NSString *host, NSInteger port, NSString *selector,
                       NSError **outError)
{
    const char *hostC = [host UTF8String];
    char portC[16];
    snprintf(portC, sizeof(portC), "%ld", (long)port);

    struct addrinfo hints;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;      // IPv4 or IPv6
    hints.ai_socktype = SOCK_STREAM;

    struct addrinfo *res = NULL;
    int gai = getaddrinfo(hostC, portC, &hints, &res);
    if (gai != 0 || res == NULL) {
        if (outError) {
            *outError = DTMakeError(DTGopherErrorResolve,
                [NSString stringWithFormat:@"Could not resolve host “%@”.", host]);
        }
        return nil;
    }

    int fd = -1;
    struct addrinfo *ai;
    BOOL timedOut = NO;
    for (ai = res; ai != NULL; ai = ai->ai_next) {
        fd = DTConnectWithTimeout(ai, DT_CONNECT_TIMEOUT);
        if (fd >= 0) {
            break;
        }
        timedOut = YES; // best-effort classification
    }
    freeaddrinfo(res);

    if (fd < 0) {
        if (outError) {
            *outError = DTMakeError(timedOut ? DTGopherErrorConnect : DTGopherErrorConnect,
                [NSString stringWithFormat:@"Could not connect to %@:%ld.", host, (long)port]);
        }
        return nil;
    }

    // Apply a read timeout for the whole receive phase.
    struct timeval rtv;
    rtv.tv_sec = DT_READ_TIMEOUT;
    rtv.tv_usec = 0;
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &rtv, sizeof(rtv));
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &rtv, sizeof(rtv));

    // Send the request line: selector + CRLF.
    NSString *requestLine = [selector stringByAppendingString:@"\r\n"];
    NSData *reqData = [requestLine dataUsingEncoding:NSUTF8StringEncoding];
    const char *reqBytes = [reqData bytes];
    NSUInteger reqLen = [reqData length];
    NSUInteger sent = 0;
    while (sent < reqLen) {
        ssize_t n = send(fd, reqBytes + sent, reqLen - sent, 0);
        if (n <= 0) {
            close(fd);
            if (outError) {
                *outError = DTMakeError(DTGopherErrorSend, @"Failed to send the request.");
            }
            return nil;
        }
        sent += (NSUInteger)n;
    }

    // Read to EOF.
    NSMutableData *out = [NSMutableData data];
    char buf[8192];
    for (;;) {
        ssize_t n = recv(fd, buf, sizeof(buf), 0);
        if (n > 0) {
            [out appendBytes:buf length:(NSUInteger)n];
        } else if (n == 0) {
            break; // clean EOF
        } else {
            close(fd);
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                if (outError) {
                    *outError = DTMakeError(DTGopherErrorTimeout, @"The server stopped responding.");
                }
            } else {
                if (outError) {
                    *outError = DTMakeError(DTGopherErrorRead, @"Error reading from the server.");
                }
            }
            return nil;
        }
    }

    close(fd);
    return out;
}

@implementation GopherRequest

@synthesize host = _host;
@synthesize port = _port;
@synthesize selector = _selector;
@synthesize delegate = _delegate;

+ (id)requestWithHost:(NSString *)host
                 port:(NSInteger)port
             selector:(NSString *)selector
{
    GopherRequest *r = [[[self alloc] init] autorelease];
    [r setHost:host];
    [r setPort:(port > 0 ? port : 70)];
    [r setSelector:(selector ? selector : @"")];
    return r;
}

- (void)dealloc
{
    [_host release];
    [_selector release];
    [super dealloc];
}

- (void)start
{
    if (_running) {
        return;
    }
    _running = YES;

    // Snapshot the request parameters; they are immutable after -start.
    NSString *host = [[_host copy] autorelease];
    NSInteger port = _port;
    NSString *selector = [[_selector copy] autorelease];

    // The blocks capture (and thus retain) self across the async hop, keeping
    // the receiver alive until the transaction completes even if the caller
    // releases its reference right after -start.
    DTAsyncBackground(^{
        NSError *error = nil;
        NSData *data = DTFetch(host, port, selector, &error);

        DTAsyncMain(^{
            if (!_cancelled) {
                if (data != nil) {
                    [_delegate gopherRequest:self didReceiveData:data];
                } else {
                    [_delegate gopherRequest:self didFailWithError:error];
                }
            }
            _running = NO;
        });
    });
}

- (void)cancel
{
    _cancelled = YES;
    _delegate = nil;
}

@end
