//
//  DTServerPrefs.m
//  DeToca — fio 8
//

#import "DTServerPrefs.h"

NSString * const DTSpotHostKey = @"DTSpotHost";
NSString * const DTSpotPortKey = @"DTSpotPort";

#define DT_SPOT_DEFAULT_HOST @"gopher.example.com"
#define DT_SPOT_DEFAULT_PORT 70

@implementation DTServerPrefs

+ (NSString *)trimmedHost:(NSString *)host
{
    if (host == nil) {
        return @"";
    }
    return [host stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

#pragma mark - Validation

+ (BOOL)isValidHost:(NSString *)host
{
    return ([[self trimmedHost:host] length] > 0);
}

+ (BOOL)isValidPort:(NSInteger)port
{
    return (port >= 1 && port <= 65535);
}

+ (BOOL)isValidHost:(NSString *)host port:(NSInteger)port
{
    return ([self isValidHost:host] && [self isValidPort:port]);
}

#pragma mark - Effective values

+ (NSString *)defaultHost { return DT_SPOT_DEFAULT_HOST; }
+ (NSInteger)defaultPort  { return DT_SPOT_DEFAULT_PORT; }

+ (NSString *)host
{
    NSString *stored = [[NSUserDefaults standardUserDefaults]
                        objectForKey:DTSpotHostKey];
    stored = [self trimmedHost:stored];
    return ([stored length] > 0) ? stored : DT_SPOT_DEFAULT_HOST;
}

+ (NSInteger)port
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d objectForKey:DTSpotPortKey] == nil) {
        return DT_SPOT_DEFAULT_PORT;
    }
    NSInteger p = [d integerForKey:DTSpotPortKey];
    return [self isValidPort:p] ? p : DT_SPOT_DEFAULT_PORT;
}

#pragma mark - Persist

+ (BOOL)saveHost:(NSString *)host port:(NSInteger)port
{
    NSString *trimmed = [self trimmedHost:host];
    if (![self isValidHost:trimmed port:port]) {
        return NO;
    }

    BOOL changed = (![trimmed isEqualToString:[self host]] || port != [self port]);

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:trimmed forKey:DTSpotHostKey];
    [d setInteger:port forKey:DTSpotPortKey];
    [d synchronize];

    return changed;
}

@end
