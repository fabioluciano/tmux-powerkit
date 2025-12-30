// =============================================================================
// powerkit-temperature - Native macOS temperature helper for tmux-powerkit
// =============================================================================
// Uses IOKit to read thermal sensors on both Intel and Apple Silicon Macs.
//
// Usage:
//   powerkit-temperature           # Returns highest CPU temperature
//   powerkit-temperature -a        # Returns all sensors (name:temp separated by \x1F)
//   powerkit-temperature -s KEY    # Returns specific sensor by SMC key
//   powerkit-temperature -l        # List available sensor keys
//
// Output format:
//   Default: <temperature_celsius>
//   -a flag: key1:temp1\x1Fkey2:temp2\x1F...
//   -s flag: <temperature_celsius>
//
// Returns exit code 1 if temperature cannot be read.
//
// Compile:
//   clang -framework Foundation -framework IOKit -o powerkit-temperature powerkit-temperature.m
// =============================================================================

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

// Record separator for -a output
#define RECORD_SEP "\x1F"

// =============================================================================
// SMC types (for both Intel and Apple Silicon)
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

// =============================================================================
// Sensor definitions
// =============================================================================

typedef struct {
    const char *key;
    const char *description;
} SensorInfo;

// All known temperature sensors
static SensorInfo allSensors[] = {
    // Apple Silicon M1/M2/M3 CPU cores
    {"Tp09", "CPU E-Core 1"},
    {"Tp0T", "CPU P-Core 1"},
    {"Tp01", "CPU Core 1"},
    {"Tp05", "CPU Core 2"},
    {"Tp0D", "CPU Core 3"},
    {"Tp0H", "CPU Core 4"},
    {"Tp0L", "CPU Core 5"},
    {"Tp0P", "CPU Core 6"},
    {"Tp0X", "CPU Core 7"},
    {"Tp0b", "CPU Core 8"},
    {"Tp0f", "CPU P-Cluster"},
    {"Tp0j", "CPU E-Cluster"},
    {"Tp1h", "CPU P-Core 2"},
    {"Tp1t", "CPU E-Core 2"},
    // Apple Silicon GPU
    {"Tg0f", "GPU Cluster"},
    {"Tg0j", "GPU Core"},
    // Apple Silicon SoC
    {"Ts0P", "SoC Proximity"},
    {"Ts0S", "SoC Core"},
    {"Ts1P", "SoC ANE"},
    // Intel Mac CPU
    {"TC0P", "CPU Proximity"},
    {"TC0D", "CPU Die"},
    {"TC0H", "CPU Heatsink"},
    {"TC0F", "CPU Die 2"},
    {"TCXC", "CPU PECI"},
    {"TC1C", "CPU Core 1"},
    {"TC2C", "CPU Core 2"},
    {"TC3C", "CPU Core 3"},
    {"TC4C", "CPU Core 4"},
    // Intel Mac GPU
    {"TCGc", "GPU PECI"},
    {"TCGC", "GPU Cluster"},
    {"TG0P", "GPU Proximity"},
    {"TG0D", "GPU Die"},
    // Memory
    {"Tm0P", "Memory Proximity"},
    {"TM0S", "Memory Slot"},
    // Storage
    {"TH0P", "HDD Proximity"},
    {"TN0P", "NVMe"},
    // Battery
    {"TB0T", "Battery"},
    {"TB1T", "Battery 2"},
    // Ambient
    {"TA0P", "Ambient"},
    {"TW0P", "WiFi"},
    {NULL, NULL}};

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

    // fpe2: fixed point 14.2 format (used by some sensors)
    if (strcmp(val->dataType, "fpe2") == 0 && val->dataSize == 2) {
        int intValue = ((unsigned char)val->bytes[0] << 8) | (unsigned char)val->bytes[1];
        return intValue / 4.0;
    }

    return -1.0;
}

// Read temperature from a specific key
static float readSensorTemperature(const char *key) {
    SMCVal_t val;
    kern_return_t result = SMCReadKey(key, &val);
    if (result != kIOReturnSuccess || val.dataSize == 0) {
        return -1.0;
    }
    return parseTemperature(&val);
}

// =============================================================================
// Temperature reading modes
// =============================================================================

// Get highest CPU temperature (default behavior)
static float getHighestTemperature(void) {
    float maxTemp = -1.0;

    for (int i = 0; allSensors[i].key != NULL; i++) {
        float t = readSensorTemperature(allSensors[i].key);
        if (t > 0 && t < 150 && t > maxTemp) {
            maxTemp = t;
        }
    }

    return maxTemp;
}

// Get all available sensors
static void getAllTemperatures(void) {
    BOOL first = YES;

    for (int i = 0; allSensors[i].key != NULL; i++) {
        float t = readSensorTemperature(allSensors[i].key);
        if (t > 0 && t < 150) {
            if (!first) {
                printf(RECORD_SEP);
            }
            printf("%s:%.0f", allSensors[i].key, t);
            first = NO;
        }
    }
    printf("\n");
}

// Get specific sensor
static float getSpecificTemperature(const char *key) {
    return readSensorTemperature(key);
}

// List available sensors
static void listSensors(void) {
    printf("Available temperature sensors:\n");
    printf("%-8s %-20s %s\n", "Key", "Description", "Current");
    printf("%-8s %-20s %s\n", "---", "-----------", "-------");

    for (int i = 0; allSensors[i].key != NULL; i++) {
        float t = readSensorTemperature(allSensors[i].key);
        if (t > 0 && t < 150) {
            printf("%-8s %-20s %.0f°C\n", allSensors[i].key, allSensors[i].description, t);
        }
    }
}

// =============================================================================
// Usage
// =============================================================================

static void printUsage(const char *progname) {
    fprintf(stderr, "Usage: %s [options]\n", progname);
    fprintf(stderr, "Options:\n");
    fprintf(stderr, "  -a          Show all available sensors (format: key:temp\\x1F...)\n");
    fprintf(stderr, "  -s KEY      Show specific sensor by SMC key (e.g., Tp0f, TC0P)\n");
    fprintf(stderr, "  -l          List available sensors with descriptions\n");
    fprintf(stderr, "  -h          Show this help\n");
    fprintf(stderr, "\nExamples:\n");
    fprintf(stderr, "  %s              # Highest temperature\n", progname);
    fprintf(stderr, "  %s -a           # All sensors\n", progname);
    fprintf(stderr, "  %s -s Tp0f      # CPU P-Cluster temperature\n", progname);
    fprintf(stderr, "  %s -l           # List sensors\n", progname);
}

// =============================================================================
// Main
// =============================================================================

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        // Parse arguments
        BOOL showAll = NO;
        BOOL listAll = NO;
        const char *specificKey = NULL;

        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "-a") == 0) {
                showAll = YES;
            } else if (strcmp(argv[i], "-l") == 0) {
                listAll = YES;
            } else if (strcmp(argv[i], "-s") == 0 && i + 1 < argc) {
                specificKey = argv[++i];
            } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
                printUsage(argv[0]);
                return 0;
            } else {
                fprintf(stderr, "Unknown option: %s\n", argv[i]);
                printUsage(argv[0]);
                return 1;
            }
        }

        // Open SMC connection
        kern_return_t result = SMCOpen();
        if (result != kIOReturnSuccess) {
            fprintf(stderr, "Error: Could not open SMC connection\n");
            return 1;
        }

        // Execute requested mode
        if (listAll) {
            listSensors();
            SMCClose();
            return 0;
        }

        if (showAll) {
            getAllTemperatures();
            SMCClose();
            return 0;
        }

        float temperature;
        if (specificKey) {
            temperature = getSpecificTemperature(specificKey);
            if (temperature < 0) {
                fprintf(stderr, "Error: Sensor '%s' not available\n", specificKey);
                SMCClose();
                return 1;
            }
        } else {
            temperature = getHighestTemperature();
        }

        SMCClose();

        if (temperature < 0) {
            fprintf(stderr, "Error: Could not read temperature\n");
            return 1;
        }

        if (temperature > 150) {
            fprintf(stderr, "Error: Invalid temperature reading: %.1f\n", temperature);
            return 1;
        }

        printf("%.0f\n", temperature);
        return 0;
    }
}
