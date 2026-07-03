//
//  DTServerPrefs.h
//  DeToca — fio 8
//
//  The gopher-spot backend address, as a preference. One source of truth for
//  the NSUserDefaults keys, the homelab defaults, and the host/port validation
//  that gates the Preferences "Save" button. Reused by openRadinho: (reading)
//  and the Preferences window (reading + writing).
//
//  The keys are the pre-existing DTSpotHost / DTSpotPort, so a legacy
//  `defaults write dev.debene.detoca DTSpotHost …` keeps working and the window
//  reads/writes the very same values. Pure Foundation — unit-testable.
//

#import <Foundation/Foundation.h>

extern NSString * const DTSpotHostKey;   // @"DTSpotHost"
extern NSString * const DTSpotPortKey;   // @"DTSpotPort"

@interface DTServerPrefs : NSObject

// --- Validation (Save button gating) ---
+ (BOOL)isValidHost:(NSString *)host;              // non-empty after trimming
+ (BOOL)isValidPort:(NSInteger)port;               // 1...65535
+ (BOOL)isValidHost:(NSString *)host port:(NSInteger)port;

// --- Effective values (defaults-backed; never invalid) ---
+ (NSString *)host;          // stored host, or defaultHost if unset/empty
+ (NSInteger)port;           // stored port, or defaultPort if unset
+ (NSString *)defaultHost;   // the homelab default
+ (NSInteger)defaultPort;    // 70

// Persist host+port. Trims the host. Returns YES if either effective value
// actually changed (so the caller knows whether to reconnect). Callers should
// validate first; an invalid host/port is rejected (returns NO, no write).
+ (BOOL)saveHost:(NSString *)host port:(NSInteger)port;

@end
