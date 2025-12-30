// =============================================================================
// powerkit-brightness - Native macOS brightness helper for tmux-powerkit
// =============================================================================
// Uses DisplayServices private framework for reliable brightness reading.
//
// Output format (one line per display):
//   <display_id>:<type>:<brightness>
// Where:
//   - display_id: CGDirectDisplayID
//   - type: builtin or external
//   - brightness: 0-100 percentage, or -1 if not available
//
// Note: External monitors using DDC/CI are listed but brightness returns -1
//       as they don't support DisplayServices API.
//
// Compile:
//   clang -framework Foundation -framework IOKit -framework ApplicationServices \
//         -F /System/Library/PrivateFrameworks -framework DisplayServices \
//         -o powerkit-brightness powerkit-brightness.m
// =============================================================================

#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import <IOKit/graphics/IOGraphicsLib.h>

// DisplayServices private framework declaration
extern int DisplayServicesGetBrightness(CGDirectDisplayID display, float *brightness);

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        CGDirectDisplayID displays[16];
        uint32_t displayCount = 0;

        CGError err = CGGetActiveDisplayList(16, displays, &displayCount);
        if (err != kCGErrorSuccess || displayCount == 0) {
            return 1;
        }

        for (uint32_t i = 0; i < displayCount; i++) {
            CGDirectDisplayID displayID = displays[i];
            float brightness = -1;
            int gotBrightness = 0;

            BOOL isBuiltin = CGDisplayIsBuiltin(displayID);
            const char *type = isBuiltin ? "builtin" : "external";

            int dsResult = DisplayServicesGetBrightness(displayID, &brightness);
            if (dsResult == 0 && brightness >= 0) {
                gotBrightness = 1;
            }

            if (gotBrightness) {
                int percentage = (int)(brightness * 100 + 0.5);
                printf("%u:%s:%d\n", displayID, type, percentage);
            } else {
                printf("%u:%s:-1\n", displayID, type);
            }
        }
    }
    return 0;
}
