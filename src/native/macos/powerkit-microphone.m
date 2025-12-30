// =============================================================================
// powerkit-microphone - Native macOS microphone status helper for tmux-powerkit
// =============================================================================
// Uses CoreAudio to detect microphone usage and mute status on macOS.
//
// Usage:
//   powerkit-microphone              # Returns: active|inactive\x1Fmuted|unmuted\x1Fvolume
//   powerkit-microphone -a           # Returns active status (active/inactive)
//   powerkit-microphone -m           # Returns mute status (muted/unmuted)
//   powerkit-microphone -v           # Returns input volume (0-100)
//   powerkit-microphone -l           # List input devices
//
// Output format (default):
//   status\x1Fmute\x1Fvolume
//   Example: active\x1Funmuted\x1F75
//
// Returns exit code 1 if no input device available.
//
// Compile:
//   clang -framework Foundation -framework CoreAudio -framework AudioToolbox -o powerkit-microphone
//   powerkit-microphone.m
// =============================================================================

#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudio.h>
#import <Foundation/Foundation.h>

// =============================================================================
// Helper Functions
// =============================================================================

// Get the default input device
static AudioDeviceID getDefaultInputDevice(void) {
    AudioDeviceID deviceID = kAudioObjectUnknown;
    UInt32 dataSize = sizeof(deviceID);

    AudioObjectPropertyAddress propertyAddress = {kAudioHardwarePropertyDefaultInputDevice,
                                                  kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};

    OSStatus status =
        AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &dataSize, &deviceID);

    if (status != noErr) {
        return kAudioObjectUnknown;
    }

    return deviceID;
}

// Check if input device is running (being used by any app)
static BOOL isInputDeviceRunning(AudioDeviceID deviceID) {
    if (deviceID == kAudioObjectUnknown) {
        return NO;
    }

    UInt32 isRunning = 0;
    UInt32 dataSize = sizeof(isRunning);

    // Check if device is running somewhere (any app using it)
    AudioObjectPropertyAddress propertyAddress = {kAudioDevicePropertyDeviceIsRunningSomewhere,
                                                  kAudioObjectPropertyScopeInput, kAudioObjectPropertyElementMain};

    OSStatus status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, NULL, &dataSize, &isRunning);

    if (status != noErr) {
        // Fallback: check if device is running at all
        propertyAddress.mSelector = kAudioDevicePropertyDeviceIsRunning;
        status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, NULL, &dataSize, &isRunning);
    }

    return (status == noErr && isRunning != 0);
}

// Get mute status of input device
static BOOL isInputMuted(AudioDeviceID deviceID) {
    if (deviceID == kAudioObjectUnknown) {
        return NO;
    }

    UInt32 muted = 0;
    UInt32 dataSize = sizeof(muted);

    AudioObjectPropertyAddress propertyAddress = {kAudioDevicePropertyMute, kAudioObjectPropertyScopeInput,
                                                  kAudioObjectPropertyElementMain};

    // First check if property exists
    if (!AudioObjectHasProperty(deviceID, &propertyAddress)) {
        // Try master element
        propertyAddress.mElement = kAudioObjectPropertyElementMain;
        if (!AudioObjectHasProperty(deviceID, &propertyAddress)) {
            return NO;
        }
    }

    OSStatus status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, NULL, &dataSize, &muted);

    return (status == noErr && muted != 0);
}

// Get input volume (0.0 - 1.0)
static Float32 getInputVolume(AudioDeviceID deviceID) {
    if (deviceID == kAudioObjectUnknown) {
        return -1.0f;
    }

    Float32 volume = 0.0f;
    UInt32 dataSize = sizeof(volume);

    // Try to get volume from input scope
    AudioObjectPropertyAddress propertyAddress = {kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeInput,
                                                  kAudioObjectPropertyElementMain};

    // Check if property exists on main element
    if (!AudioObjectHasProperty(deviceID, &propertyAddress)) {
        // Try element 1 (first channel)
        propertyAddress.mElement = 1;
        if (!AudioObjectHasProperty(deviceID, &propertyAddress)) {
            return -1.0f;
        }
    }

    OSStatus status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, NULL, &dataSize, &volume);

    if (status != noErr) {
        return -1.0f;
    }

    return volume;
}

// Get device name
static NSString *getDeviceName(AudioDeviceID deviceID) {
    if (deviceID == kAudioObjectUnknown) {
        return @"Unknown";
    }

    CFStringRef deviceName = NULL;
    UInt32 dataSize = sizeof(deviceName);

    AudioObjectPropertyAddress propertyAddress = {kAudioDevicePropertyDeviceNameCFString,
                                                  kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};

    OSStatus status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, NULL, &dataSize, &deviceName);

    if (status != noErr || deviceName == NULL) {
        return @"Unknown";
    }

    NSString *name = (NSString *)CFBridgingRelease(deviceName);
    return name;
}

// List all input devices
static void listInputDevices(void) {
    AudioObjectPropertyAddress propertyAddress = {kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal,
                                                  kAudioObjectPropertyElementMain};

    UInt32 dataSize = 0;
    OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &dataSize);

    if (status != noErr) {
        printf("No audio devices found\n");
        return;
    }

    UInt32 deviceCount = dataSize / sizeof(AudioDeviceID);
    AudioDeviceID *deviceIDs = (AudioDeviceID *)malloc(dataSize);

    status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &dataSize, deviceIDs);

    if (status != noErr) {
        free(deviceIDs);
        printf("Failed to get audio devices\n");
        return;
    }

    printf("Input devices:\n");
    printf("%-40s %-10s %-10s %-10s\n", "Name", "Running", "Muted", "Volume");
    printf("%-40s %-10s %-10s %-10s\n", "----", "-------", "-----", "------");

    AudioDeviceID defaultInput = getDefaultInputDevice();

    for (UInt32 i = 0; i < deviceCount; i++) {
        AudioDeviceID deviceID = deviceIDs[i];

        // Check if this device has input capabilities
        AudioObjectPropertyAddress inputAddress = {kAudioDevicePropertyStreamConfiguration,
                                                   kAudioObjectPropertyScopeInput, kAudioObjectPropertyElementMain};

        UInt32 configSize = 0;
        status = AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, NULL, &configSize);

        if (status != noErr || configSize == 0) {
            continue; // No input streams
        }

        AudioBufferList *bufferList = (AudioBufferList *)malloc(configSize);
        status = AudioObjectGetPropertyData(deviceID, &inputAddress, 0, NULL, &configSize, bufferList);

        BOOL hasInput = NO;
        if (status == noErr) {
            for (UInt32 j = 0; j < bufferList->mNumberBuffers; j++) {
                if (bufferList->mBuffers[j].mNumberChannels > 0) {
                    hasInput = YES;
                    break;
                }
            }
        }
        free(bufferList);

        if (!hasInput) {
            continue;
        }

        NSString *name = getDeviceName(deviceID);
        BOOL isRunning = isInputDeviceRunning(deviceID);
        BOOL isMuted = isInputMuted(deviceID);
        Float32 volume = getInputVolume(deviceID);

        const char *defaultMarker = (deviceID == defaultInput) ? " *" : "";
        const char *runningStr = isRunning ? "Yes" : "No";
        const char *mutedStr = isMuted ? "Yes" : "No";

        if (volume >= 0) {
            printf("%-40s %-10s %-10s %d%%%s\n", [name UTF8String], runningStr, mutedStr, (int)(volume * 100),
                   defaultMarker);
        } else {
            printf("%-40s %-10s %-10s N/A%s\n", [name UTF8String], runningStr, mutedStr, defaultMarker);
        }
    }

    free(deviceIDs);
    printf("\n* = Default input device\n");
}

// =============================================================================
// Usage
// =============================================================================

static void printUsage(const char *progname) {
    fprintf(stderr, "Usage: %s [options]\n", progname);
    fprintf(stderr, "Options:\n");
    fprintf(stderr, "  (none)      Show all info (format: status<sep>mute<sep>volume)\n");
    fprintf(stderr, "  -a          Show active status only (active/inactive)\n");
    fprintf(stderr, "  -m          Show mute status only (muted/unmuted)\n");
    fprintf(stderr, "  -v          Show input volume only (0-100)\n");
    fprintf(stderr, "  -l          List input devices\n");
    fprintf(stderr, "  -h          Show this help\n");
    fprintf(stderr, "\nExamples:\n");
    fprintf(stderr, "  %s              # active<sep>unmuted<sep>75\n", progname);
    fprintf(stderr, "  %s -a           # active\n", progname);
    fprintf(stderr, "  %s -m           # unmuted\n", progname);
    fprintf(stderr, "\nNote: <sep> = ASCII 0x1F (unit separator)\n");
}

// =============================================================================
// Main
// =============================================================================

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        // Parse arguments
        BOOL showActive = NO;
        BOOL showMute = NO;
        BOOL showVolume = NO;
        BOOL showAll = NO;
        BOOL listAll = NO;

        if (argc == 1) {
            showAll = YES;
        }

        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "-a") == 0) {
                showActive = YES;
            } else if (strcmp(argv[i], "-m") == 0) {
                showMute = YES;
            } else if (strcmp(argv[i], "-v") == 0) {
                showVolume = YES;
            } else if (strcmp(argv[i], "-l") == 0) {
                listAll = YES;
            } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
                printUsage(argv[0]);
                return 0;
            } else {
                fprintf(stderr, "Unknown option: %s\n", argv[i]);
                printUsage(argv[0]);
                return 1;
            }
        }

        // List mode
        if (listAll) {
            listInputDevices();
            return 0;
        }

        // Get default input device
        AudioDeviceID inputDevice = getDefaultInputDevice();

        if (inputDevice == kAudioObjectUnknown) {
            if (showAll) {
                printf("inactive\x1F"
                       "unmuted\x1F"
                       "0\n");
            } else if (showActive) {
                printf("inactive\n");
            } else if (showMute) {
                printf("unmuted\n");
            } else if (showVolume) {
                printf("0\n");
            }
            return 1;
        }

        // Get status
        BOOL isRunning = isInputDeviceRunning(inputDevice);
        BOOL isMuted = isInputMuted(inputDevice);
        Float32 volume = getInputVolume(inputDevice);
        int volumePercent = (volume >= 0) ? (int)(volume * 100) : 0;

        const char *activeStr = isRunning ? "active" : "inactive";
        const char *muteStr = isMuted ? "muted" : "unmuted";

        // Output based on mode
        if (showAll) {
            printf("%s\x1F"
                   "%s\x1F"
                   "%d\n",
                   activeStr, muteStr, volumePercent);
        } else if (showActive) {
            printf("%s\n", activeStr);
        } else if (showMute) {
            printf("%s\n", muteStr);
        } else if (showVolume) {
            printf("%d\n", volumePercent);
        }

        return 0;
    }
}
