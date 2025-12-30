// =============================================================================
// powerkit-gpu - Native macOS GPU helper for tmux-powerkit
// =============================================================================
// Uses IOKit to read GPU statistics on both Intel and Apple Silicon Macs.
//
// Usage:
//   powerkit-gpu              # Returns GPU usage percentage (default)
//   powerkit-gpu -u           # Returns GPU usage percentage
//   powerkit-gpu -t           # Returns GPU temperature (°C)
//   powerkit-gpu -m           # Returns GPU memory (usedMB\x1FtotalMB)
//   powerkit-gpu -a           # Returns all metrics (usage\x1FmemUsedMB\x1FmemTotalMB\x1Ftemp)
//   powerkit-gpu -l           # List available GPUs
//
// Output format:
//   Default: <percentage>
//   -m flag: usedMB\x1FtotalMB
//   -a flag: usage\x1FmemUsedMB\x1FmemTotalMB\x1Ftemp
//
// Returns exit code 1 if metrics cannot be read.
//
// Compile:
//   clang -framework Foundation -framework IOKit -o powerkit-gpu powerkit-gpu.m
// =============================================================================

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

// =============================================================================
// SMC types (for temperature reading)
// =============================================================================

#define KERNEL_INDEX_SMC 2

typedef struct {
    char major;
    char minor;
    char build;
    char reserved[1];
    UInt16 release;
} SMCKeyData_vers_t;

typedef struct {
    UInt16 version;
    UInt16 length;
    UInt32 cpuPLimit;
    UInt32 gpuPLimit;
    UInt32 memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
    UInt32 dataSize;
    UInt32 dataType;
    char dataAttributes;
} SMCKeyData_keyInfo_t;

typedef char SMCBytes_t[32];

typedef struct {
    UInt32 key;
    SMCKeyData_vers_t vers;
    SMCKeyData_pLimitData_t pLimitData;
    SMCKeyData_keyInfo_t keyInfo;
    char result;
    char status;
    char data8;
    UInt32 data32;
    SMCBytes_t bytes;
} SMCKeyData_t;

typedef char UInt32Char_t[5];

typedef struct {
    UInt32Char_t key;
    UInt32 dataSize;
    UInt32Char_t dataType;
    SMCBytes_t bytes;
} SMCVal_t;

enum {
    kSMCGetKeyInfo = 9,
    kSMCReadKey = 5,
};

// GPU temperature sensor keys
static const char *gpuTempKeys[] = {"Tg0f", // Apple Silicon GPU Cluster
                                    "Tg0j", // Apple Silicon GPU Core
                                    "TG0P", // Intel GPU Proximity
                                    "TG0D", // Intel GPU Die
                                    "TCGc", // Intel GPU PECI
                                    "TCGC", // Intel GPU Cluster
                                    NULL};

// =============================================================================
// SMC Helper functions
// =============================================================================

static UInt32 _strtoul(const char *str, int size, int base) {
    UInt32 total = 0;
    for (int i = 0; i < size; i++) {
        total += (unsigned char)(str[i]) << (size - 1 - i) * 8;
    }
    return total;
}

static void _ultostr(char *str, UInt32 val) {
    str[0] = '\0';
    sprintf(str, "%c%c%c%c", (unsigned int)val >> 24, (unsigned int)val >> 16, (unsigned int)val >> 8,
            (unsigned int)val);
}

static io_connect_t g_conn = 0;

static kern_return_t SMCOpen(void) {
    kern_return_t result;
    io_iterator_t iterator;
    io_object_t device;

    CFMutableDictionaryRef matchingDictionary = IOServiceMatching("AppleSMC");
    result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDictionary, &iterator);
    if (result != kIOReturnSuccess) {
        return result;
    }

    device = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
    if (device == 0) {
        return kIOReturnNoDevice;
    }

    result = IOServiceOpen(device, mach_task_self(), 0, &g_conn);
    IOObjectRelease(device);

    return result;
}

static kern_return_t SMCClose(void) {
    return IOServiceClose(g_conn);
}

static kern_return_t SMCCall(int index, SMCKeyData_t *inputStructure, SMCKeyData_t *outputStructure) {
    size_t structureInputSize = sizeof(SMCKeyData_t);
    size_t structureOutputSize = sizeof(SMCKeyData_t);

    return IOConnectCallStructMethod(g_conn, index, inputStructure, structureInputSize, outputStructure,
                                     &structureOutputSize);
}

static kern_return_t SMCReadKey(const char *key, SMCVal_t *val) {
    kern_return_t result;
    SMCKeyData_t inputStructure;
    SMCKeyData_t outputStructure;

    memset(&inputStructure, 0, sizeof(SMCKeyData_t));
    memset(&outputStructure, 0, sizeof(SMCKeyData_t));
    memset(val, 0, sizeof(SMCVal_t));

    inputStructure.key = _strtoul(key, 4, 16);
    inputStructure.data8 = kSMCGetKeyInfo;

    result = SMCCall(KERNEL_INDEX_SMC, &inputStructure, &outputStructure);
    if (result != kIOReturnSuccess) {
        return result;
    }

    val->dataSize = outputStructure.keyInfo.dataSize;
    _ultostr(val->dataType, outputStructure.keyInfo.dataType);
    inputStructure.keyInfo.dataSize = val->dataSize;
    inputStructure.data8 = kSMCReadKey;

    result = SMCCall(KERNEL_INDEX_SMC, &inputStructure, &outputStructure);
    if (result != kIOReturnSuccess) {
        return result;
    }

    memcpy(val->bytes, outputStructure.bytes, sizeof(outputStructure.bytes));

    return kIOReturnSuccess;
}

// Parse temperature from SMC value
static float parseTemperature(SMCVal_t *val) {
    if (val->dataSize == 0) {
        return -1.0;
    }

    // sp78: signed fixed-point 7.8 format (most common)
    if (strcmp(val->dataType, "sp78") == 0 && val->dataSize == 2) {
        int intValue = ((signed char)val->bytes[0] << 8) | (unsigned char)val->bytes[1];
        return intValue / 256.0;
    }

    // flt: float format
    if (strcmp(val->dataType, "flt ") == 0 && val->dataSize == 4) {
        float temp;
        memcpy(&temp, val->bytes, sizeof(float));
        return temp;
    }

    // fp79: unsigned fixed-point 7.9 format
    if (strcmp(val->dataType, "fp79") == 0 && val->dataSize == 2) {
        int intValue = ((unsigned char)val->bytes[0] << 8) | (unsigned char)val->bytes[1];
        return intValue / 512.0;
    }

    // sp87: signed fixed-point 8.7 format
    if (strcmp(val->dataType, "sp87") == 0 && val->dataSize == 2) {
        int intValue = ((signed char)val->bytes[0] << 8) | (unsigned char)val->bytes[1];
        return intValue / 128.0;
    }

    return -1.0;
}

// =============================================================================
// GPU Temperature
// =============================================================================

static float getGPUTemperature(void) {
    SMCVal_t val;

    for (int i = 0; gpuTempKeys[i] != NULL; i++) {
        kern_return_t result = SMCReadKey(gpuTempKeys[i], &val);
        if (result == kIOReturnSuccess && val.dataSize > 0) {
            float temp = parseTemperature(&val);
            if (temp > 0 && temp < 150) {
                return temp;
            }
        }
    }

    return -1.0;
}

// =============================================================================
// GPU Usage via IOAccelerator
// =============================================================================

static int getGPUUsageAndMemory(int *usage, int64_t *memUsedBytes, int64_t *memTotalBytes) {
    *usage = -1;
    *memUsedBytes = -1;
    *memTotalBytes = -1;

    // Find AGX Accelerator (Apple Silicon) or IOAccelerator services
    io_iterator_t iterator;
    CFMutableDictionaryRef matchDict = IOServiceMatching("IOAccelerator");

    kern_return_t result = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator);

    if (result != kIOReturnSuccess) {
        return 0;
    }

    io_object_t service;
    BOOL found = NO;

    while ((service = IOIteratorNext(iterator)) != 0) {
        CFMutableDictionaryRef properties = NULL;

        result =
            IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, kIORegistryIterateRecursively);

        if (result == kIOReturnSuccess && properties != NULL) {
            // Get PerformanceStatistics
            CFDictionaryRef perfStats = CFDictionaryGetValue(properties, CFSTR("PerformanceStatistics"));

            if (perfStats != NULL && CFGetTypeID(perfStats) == CFDictionaryGetTypeID()) {
                // Try to get Device Utilization %
                CFNumberRef utilizationRef = CFDictionaryGetValue(perfStats, CFSTR("Device Utilization %"));
                if (utilizationRef != NULL && CFGetTypeID(utilizationRef) == CFNumberGetTypeID()) {
                    int64_t utilization = 0;
                    if (CFNumberGetValue(utilizationRef, kCFNumberSInt64Type, &utilization)) {
                        *usage = (int)utilization;
                        found = YES;
                    }
                }

                // Alternative: try Renderer Utilization %
                if (*usage < 0) {
                    CFNumberRef rendererRef = CFDictionaryGetValue(perfStats, CFSTR("Renderer Utilization %"));
                    if (rendererRef != NULL && CFGetTypeID(rendererRef) == CFNumberGetTypeID()) {
                        int64_t renderer = 0;
                        if (CFNumberGetValue(rendererRef, kCFNumberSInt64Type, &renderer)) {
                            *usage = (int)renderer;
                            found = YES;
                        }
                    }
                }

                // Alternative: try GPU Activity(%)
                if (*usage < 0) {
                    CFNumberRef activityRef = CFDictionaryGetValue(perfStats, CFSTR("GPU Activity(%)"));
                    if (activityRef != NULL && CFGetTypeID(activityRef) == CFNumberGetTypeID()) {
                        int64_t activity = 0;
                        if (CFNumberGetValue(activityRef, kCFNumberSInt64Type, &activity)) {
                            *usage = (int)activity;
                            found = YES;
                        }
                    }
                }

                // Try to get memory usage - "In use system memory" (bytes)
                CFNumberRef memUsedRef = CFDictionaryGetValue(perfStats, CFSTR("In use system memory"));
                CFNumberRef memAllocRef = CFDictionaryGetValue(perfStats, CFSTR("Alloc system memory"));

                if (memUsedRef != NULL && CFGetTypeID(memUsedRef) == CFNumberGetTypeID()) {
                    CFNumberGetValue(memUsedRef, kCFNumberSInt64Type, memUsedBytes);

                    if (memAllocRef != NULL && CFGetTypeID(memAllocRef) == CFNumberGetTypeID()) {
                        CFNumberGetValue(memAllocRef, kCFNumberSInt64Type, memTotalBytes);
                    }
                }

                // Alternative: vramUsedBytes / vramFreeBytes (Intel Macs)
                if (*memUsedBytes < 0) {
                    CFNumberRef vramUsedRef = CFDictionaryGetValue(perfStats, CFSTR("vramUsedBytes"));
                    CFNumberRef vramFreeRef = CFDictionaryGetValue(perfStats, CFSTR("vramFreeBytes"));

                    if (vramUsedRef != NULL && vramFreeRef != NULL) {
                        int64_t vramFree = 0;
                        CFNumberGetValue(vramUsedRef, kCFNumberSInt64Type, memUsedBytes);
                        CFNumberGetValue(vramFreeRef, kCFNumberSInt64Type, &vramFree);
                        *memTotalBytes = *memUsedBytes + vramFree;
                    }
                }
            }

            CFRelease(properties);
        }

        IOObjectRelease(service);

        if (found)
            break; // Use first GPU with valid data
    }

    IOObjectRelease(iterator);

    return found ? 1 : 0;
}

// =============================================================================
// List GPUs
// =============================================================================

static void listGPUs(void) {
    printf("Available GPUs:\n");
    printf("%-40s %s\n", "Name", "Type");
    printf("%-40s %s\n", "----", "----");

    io_iterator_t iterator;
    kern_return_t result =
        IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator);

    if (result != kIOReturnSuccess) {
        printf("No GPUs found\n");
        return;
    }

    io_object_t service;
    int gpuIndex = 0;

    while ((service = IOIteratorNext(iterator)) != 0) {
        CFMutableDictionaryRef properties = NULL;

        result = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0);

        if (result == kIOReturnSuccess && properties != NULL) {
            // Get GPU name
            CFStringRef nameRef = CFDictionaryGetValue(properties, CFSTR("model"));
            if (nameRef == NULL) {
                nameRef = CFDictionaryGetValue(properties, CFSTR("IOClass"));
            }

            char name[256] = "Unknown GPU";
            if (nameRef != NULL) {
                CFStringGetCString(nameRef, name, sizeof(name), kCFStringEncodingUTF8);
            }

            // Determine type
            const char *type = "Unknown";
            CFBooleanRef integratedRef = CFDictionaryGetValue(properties, CFSTR("IOGPUIntegrated"));
            if (integratedRef != NULL) {
                type = CFBooleanGetValue(integratedRef) ? "Integrated" : "Discrete";
            } else {
                // Apple Silicon GPUs are always integrated
                if (strstr(name, "Apple") != NULL) {
                    type = "Integrated (SoC)";
                }
            }

            printf("%-40s %s\n", name, type);
            gpuIndex++;

            CFRelease(properties);
        }

        IOObjectRelease(service);
    }

    IOObjectRelease(iterator);

    if (gpuIndex == 0) {
        printf("No GPUs found\n");
    }

    // Also show available temperature sensors
    printf("\nGPU Temperature sensors:\n");

    // Open SMC
    if (SMCOpen() == kIOReturnSuccess) {
        SMCVal_t val;
        for (int i = 0; gpuTempKeys[i] != NULL; i++) {
            kern_return_t res = SMCReadKey(gpuTempKeys[i], &val);
            if (res == kIOReturnSuccess && val.dataSize > 0) {
                float temp = parseTemperature(&val);
                if (temp > 0 && temp < 150) {
                    printf("  %s: %.0f°C\n", gpuTempKeys[i], temp);
                }
            }
        }
        SMCClose();
    }
}

// =============================================================================
// Usage
// =============================================================================

static void printUsage(const char *progname) {
    fprintf(stderr, "Usage: %s [options]\n", progname);
    fprintf(stderr, "Options:\n");
    fprintf(stderr, "  -u          Show GPU usage percentage (default)\n");
    fprintf(stderr, "  -t          Show GPU temperature (°C)\n");
    fprintf(stderr, "  -m          Show GPU memory (format: usedMB\\x1FtotalMB)\n");
    fprintf(stderr, "  -a          Show all metrics (format: usage\\x1FmemUsedMB\\x1FmemTotalMB\\x1Ftemp)\n");
    fprintf(stderr, "  -l          List available GPUs\n");
    fprintf(stderr, "  -h          Show this help\n");
    fprintf(stderr, "\nExamples:\n");
    fprintf(stderr, "  %s              # GPU usage\n", progname);
    fprintf(stderr, "  %s -t           # GPU temperature\n", progname);
    fprintf(stderr, "  %s -a           # All metrics\n", progname);
}

// =============================================================================
// Main
// =============================================================================

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        // Parse arguments
        BOOL showUsage = NO;
        BOOL showTemp = NO;
        BOOL showMemory = NO;
        BOOL showAll = NO;
        BOOL listAll = NO;

        // Default: show usage
        if (argc == 1) {
            showUsage = YES;
        }

        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "-u") == 0) {
                showUsage = YES;
            } else if (strcmp(argv[i], "-t") == 0) {
                showTemp = YES;
            } else if (strcmp(argv[i], "-m") == 0) {
                showMemory = YES;
            } else if (strcmp(argv[i], "-a") == 0) {
                showAll = YES;
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
            listGPUs();
            return 0;
        }

        // Get metrics
        int usage = -1;
        int64_t memUsedBytes = -1;
        int64_t memTotalBytes = -1;
        float temp = -1.0;

        // Get usage and memory from IOAccelerator
        getGPUUsageAndMemory(&usage, &memUsedBytes, &memTotalBytes);

        // Get temperature from SMC
        if (showTemp || showAll) {
            if (SMCOpen() == kIOReturnSuccess) {
                temp = getGPUTemperature();
                SMCClose();
            }
        }

        // Helper: convert bytes to MB
        int64_t memUsedMB = memUsedBytes > 0 ? memUsedBytes / (1024 * 1024) : 0;
        int64_t memTotalMB = memTotalBytes > 0 ? memTotalBytes / (1024 * 1024) : 0;

        // Output based on mode
        if (showAll) {
            // Format: usage\x1FmemUsedMB\x1FmemTotalMB\x1Ftemp
            printf("%d\x1F%lld\x1F%lld\x1F%.0f\n", usage >= 0 ? usage : 0, memUsedMB, memTotalMB,
                   temp > 0 ? temp : 0.0);
            return 0;
        }

        if (showTemp) {
            if (temp < 0) {
                fprintf(stderr, "Error: Could not read GPU temperature\n");
                return 1;
            }
            printf("%.0f\n", temp);
            return 0;
        }

        if (showMemory) {
            if (memUsedBytes < 0) {
                fprintf(stderr, "Error: Could not read GPU memory\n");
                return 1;
            }
            // Format: usedMB\x1FtotalMB
            printf("%lld\x1F%lld\n", memUsedMB, memTotalMB);
            return 0;
        }

        // Default: show usage
        if (showUsage || argc == 1) {
            if (usage < 0) {
                // Try to get at least something
                fprintf(stderr, "Error: Could not read GPU usage\n");
                return 1;
            }
            printf("%d\n", usage);
            return 0;
        }

        return 0;
    }
}
