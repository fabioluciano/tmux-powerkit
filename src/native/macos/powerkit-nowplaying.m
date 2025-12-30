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
// Compile:
//   clang -framework Foundation -framework ScriptingBridge \
//         -o powerkit-nowplaying powerkit-nowplaying.m
// =============================================================================

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <ScriptingBridge/ScriptingBridge.h>

// Unit Separator (ASCII 31) - non-printable field delimiter
#define FIELD_SEP "\x1F"

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

// Get now playing info from Spotify
NSDictionary *getSpotifyInfo(void) {
    if (!isAppRunning(@"com.spotify.client")) {
        return nil;
    }

    @try {
        id spotify = [SBApplication applicationWithBundleIdentifier:@"com.spotify.client"];
        if (!spotify)
            return nil;

        // Get player state
        NSString *playerState = [spotify performSelector:@selector(playerState)];
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
        id track = [spotify performSelector:@selector(currentTrack)];
        if (!track)
            return nil;

        NSString *artist = [track performSelector:@selector(artist)];
        NSString *title = [track performSelector:@selector(name)];
        NSString *album = [track performSelector:@selector(album)];

        if (!title || [title length] == 0)
            return nil;

        return @{
            @"state" : state,
            @"artist" : sanitize(artist) ?: @"",
            @"title" : sanitize(title) ?: @"",
            @"album" : sanitize(album) ?: @"",
            @"app" : @"Spotify"
        };
    } @catch (NSException *e) {
        return nil;
    }
}

// Get now playing info from Music (iTunes)
NSDictionary *getMusicInfo(void) {
    if (!isAppRunning(@"com.apple.Music")) {
        return nil;
    }

    @try {
        id music = [SBApplication applicationWithBundleIdentifier:@"com.apple.Music"];
        if (!music)
            return nil;

        // Get player state
        id playerState = [music performSelector:@selector(playerState)];
        if (!playerState)
            return nil;

        // Convert state enum to string
        NSString *state;
        long stateValue = (long)playerState;
        if (stateValue == 'kPSP') { // playing
            state = @"playing";
        } else if (stateValue == 'kPSp') { // paused
            state = @"paused";
        } else {
            return nil;
        }

        // Get current track
        id track = [music performSelector:@selector(currentTrack)];
        if (!track)
            return nil;

        NSString *artist = [track performSelector:@selector(artist)];
        NSString *title = [track performSelector:@selector(name)];
        NSString *album = [track performSelector:@selector(album)];

        if (!title || [title length] == 0)
            return nil;

        return @{
            @"state" : state,
            @"artist" : sanitize(artist) ?: @"",
            @"title" : sanitize(title) ?: @"",
            @"album" : sanitize(album) ?: @"",
            @"app" : @"Music"
        };
    } @catch (NSException *e) {
        return nil;
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSDictionary *info = nil;

        // Try Spotify first (more commonly used)
        info = getSpotifyInfo();

        // Try Music if Spotify didn't return anything
        if (!info) {
            info = getMusicInfo();
        }

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
