// =============================================================================
// powerkit-nowplaying - Native macOS now playing helper for tmux-powerkit
// =============================================================================
// Uses ScriptingBridge to get now playing info from Spotify and Music apps.
// More reliable than MediaRemote for CLI tools (no entitlement issues).
//
// Output format:
//   <state>\x1F<artist>\x1F<title>\x1F<album>\x1F<app>
// Where:
//   - \x1F is the Unit Separator (ASCII 31) - non-printable delimiter
//   - state: playing, paused, or stopped
//   - artist: track artist (may be empty)
//   - title: track title
//   - album: album name (may be empty)
//   - app: application name (Spotify, Music)
//
// Usage:
//   powerkit-nowplaying [-p <priority-list>]
//
//   -p <list>  Comma-separated priority of app names (e.g. "Spotify,Music").
//              The first app in the list that is running AND has playback
//              info wins. If no app matches, fall back to the default order
//              (Spotify then Music).
//
// Compile:
//   clang -framework Foundation -framework ScriptingBridge \
//         -o powerkit-nowplaying powerkit-nowplaying.m
// =============================================================================

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <ScriptingBridge/ScriptingBridge.h>

// Unit Separator (ASCII 31) - non-printable field delimiter
#define FIELD_SEP "\x1F"

// Max apps we are willing to look up by name. Anything longer is truncated.
#define PRIORITY_MAX 16

// Sanitize string: replace control characters and newlines
NSString *sanitize(NSString *str) {
    if (!str)
        return @"";
    // Remove any Unit Separator that might be in the string
    str = [str stringByReplacingOccurrencesOfString:@"\x1F" withString:@" "];
    str = [str stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    str = [str stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    return str;
}

// Check if an application is running
BOOL isAppRunning(NSString *bundleId) {
    NSArray *apps = [[NSWorkspace sharedWorkspace] runningApplications];
    for (NSRunningApplication *app in apps) {
        if ([[app bundleIdentifier] isEqualToString:bundleId]) {
            return YES;
        }
    }
    return NO;
}

// Map a friendly app name to its bundle identifier. Returns nil if unknown.
NSString *bundleIdForName(NSString *name) {
    NSString *low = [name lowercaseString];
    if ([low isEqualToString:@"spotify"]) return @"com.spotify.client";
    if ([low isEqualToString:@"music"] || [low isEqualToString:@"apple music"]) return @"com.apple.Music";
    if ([low isEqualToString:@"itunes"]) return @"com.apple.iTunes";
    // Allow callers to pass the raw bundle id too.
    if ([low hasPrefix:@"com."]) return name;
    return nil;
}

// Get now playing info from a specific app by bundle id.
NSDictionary *getInfoForBundleId(NSString *bundleId) {
    if (!isAppRunning(bundleId)) {
        return nil;
    }

    @try {
        id app = [SBApplication applicationWithBundleIdentifier:bundleId];
        if (!app)
            return nil;

        // Get player state
        id playerState = [app performSelector:@selector(playerState)];
        if (!playerState)
            return nil;

        // Convert state enum to string
        NSString *state;
        long stateValue = (long)playerState; // It's actually an enum
        if (stateValue == 'kPSP') {          // playing
            state = @"playing";
        } else if (stateValue == 'kPSp') { // paused
            state = @"paused";
        } else {
            return nil; // stopped or unknown
        }

        // Get current track
        id track = [app performSelector:@selector(currentTrack)];
        if (!track)
            return nil;

        NSString *artist = [track performSelector:@selector(artist)];
        NSString *title = [track performSelector:@selector(name)];
        NSString *album = [track performSelector:@selector(album)];

        if (!title || [title length] == 0)
            return nil;

        // Determine friendly app name from bundle id.
        NSString *appName;
        if ([bundleId isEqualToString:@"com.spotify.client"]) {
            appName = @"Spotify";
        } else if ([bundleId isEqualToString:@"com.apple.Music"]) {
            appName = @"Music";
        } else if ([bundleId isEqualToString:@"com.apple.iTunes"]) {
            appName = @"iTunes";
        } else {
            appName = bundleId;
        }

        return @{
            @"state" : state,
            @"artist" : sanitize(artist) ?: @"",
            @"title" : sanitize(title) ?: @"",
            @"album" : sanitize(album) ?: @"",
            @"app" : appName
        };
    } @catch (NSException *e) {
        return nil;
    }
}

// Get now playing info from Spotify (default fallback order).
NSDictionary *getSpotifyInfo(void) {
    return getInfoForBundleId(@"com.spotify.client");
}

// Get now playing info from Music (iTunes).
NSDictionary *getMusicInfo(void) {
    return getInfoForBundleId(@"com.apple.Music");
}

// Split a comma-separated priority list into a C array of bundle ids.
// Returns the count. Up to PRIORITY_MAX entries are kept; longer inputs
// are silently truncated.
NSUInteger parsePriorityList(const char *raw, NSString **out) {
    if (!raw || !*raw || !out)
        return 0;
    NSString *list = [[NSString stringWithUTF8String:raw]
        stringByReplacingOccurrencesOfString:@"," withString:@" "];
    NSArray *parts = [list componentsSeparatedByString:@" "];
    NSUInteger n = 0;
    for (NSString *p in parts) {
        NSString *trimmed = [p stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];
        if ([trimmed length] == 0)
            continue;
        NSString *bid = bundleIdForName(trimmed);
        if (!bid)
            continue;
        // Avoid duplicates so a single app doesn't get queried twice.
        BOOL duplicate = NO;
        for (NSUInteger i = 0; i < n; i++) {
            if ([out[i] isEqualToString:bid]) { duplicate = YES; break; }
        }
        if (duplicate)
            continue;
        if (n >= PRIORITY_MAX)
            break;
        out[n++] = bid;
    }
    return n;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        // Parse arguments. Currently only -p <priority-list> is supported.
        NSString *priority[PRIORITY_MAX];
        for (int i = 0; i < PRIORITY_MAX; i++) priority[i] = nil;
        NSUInteger priorityCount = 0;

        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "-p") == 0 && i + 1 < argc) {
                priorityCount = parsePriorityList(argv[i + 1], priority);
                i++;
            }
            // Unknown args are silently ignored for forward compatibility.
        }

        NSDictionary *info = nil;

        // Try the user-configured priority list first.
        for (NSUInteger i = 0; i < priorityCount && !info; i++) {
            info = getInfoForBundleId(priority[i]);
        }

        // Default fallback order: Spotify then Music.
        if (!info) info = getSpotifyInfo();
        if (!info) info = getMusicInfo();

        // Nothing playing
        if (!info) {
            return 1;
        }

        // Output: state\x1Fartist\x1Ftitle\x1Falbum\x1Fapp
        printf("%s" FIELD_SEP "%s" FIELD_SEP "%s" FIELD_SEP "%s" FIELD_SEP "%s\n", [info[@"state"] UTF8String],
               [info[@"artist"] UTF8String], [info[@"title"] UTF8String], [info[@"album"] UTF8String],
               [info[@"app"] UTF8String]);

        return 0;
    }
}
