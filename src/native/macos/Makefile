# =============================================================================
# Makefile for tmux-powerkit macOS native helpers
# =============================================================================

CC = clang
ARCH ?= $(shell uname -m)

# Compilation flags with architecture
CFLAGS = -arch $(ARCH) -O2 -Wall -Wextra

# Version information (passed from build script)
ifdef VERSION
  CFLAGS += -DVERSION=\"$(VERSION)\"
endif

ifdef COMMIT
  CFLAGS += -DCOMMIT=\"$(COMMIT)\"
endif

ifdef BUILD_DATE
  CFLAGS += -DBUILD_DATE=\"$(BUILD_DATE)\"
endif

# Framework sets for different helpers
BRIGHTNESS_FRAMEWORKS = -framework Foundation -framework IOKit -framework ApplicationServices \
                        -F /System/Library/PrivateFrameworks -framework DisplayServices

NOWPLAYING_FRAMEWORKS = -framework Foundation -framework AppKit -framework ScriptingBridge

TEMPERATURE_FRAMEWORKS = -framework Foundation -framework IOKit

GPU_FRAMEWORKS = -framework Foundation -framework IOKit

MICROPHONE_FRAMEWORKS = -framework Foundation -framework CoreAudio -framework AudioToolbox

# Targets
BRIGHTNESS = powerkit-brightness
NOWPLAYING = powerkit-nowplaying
TEMPERATURE = powerkit-temperature
GPU = powerkit-gpu
MICROPHONE = powerkit-microphone

ALL_TARGETS = $(BRIGHTNESS) $(NOWPLAYING) $(TEMPERATURE) $(GPU) $(MICROPHONE)

.PHONY: all clean install info help $(ALL_TARGETS)

all: info $(ALL_TARGETS)

$(BRIGHTNESS): $(BRIGHTNESS).m
	@echo "Compiling $@..."
	@$(CC) $(CFLAGS) $(BRIGHTNESS_FRAMEWORKS) $< -o $@
	@echo "✓ $@ compiled successfully"

$(NOWPLAYING): $(NOWPLAYING).m
	@echo "Compiling $@..."
	@$(CC) $(CFLAGS) $(NOWPLAYING_FRAMEWORKS) $< -o $@
	@echo "✓ $@ compiled successfully"

$(TEMPERATURE): $(TEMPERATURE).m
	@echo "Compiling $@..."
	@$(CC) $(CFLAGS) $(TEMPERATURE_FRAMEWORKS) $< -o $@
	@echo "✓ $@ compiled successfully"

$(GPU): $(GPU).m
	@echo "Compiling $@..."
	@$(CC) $(CFLAGS) $(GPU_FRAMEWORKS) $< -o $@
	@echo "✓ $@ compiled successfully"

$(MICROPHONE): $(MICROPHONE).m
	@echo "Compiling $@..."
	@$(CC) $(CFLAGS) $(MICROPHONE_FRAMEWORKS) $< -o $@
	@echo "✓ $@ compiled successfully"

clean:
	@echo "Cleaning build artifacts..."
	@rm -f $(ALL_TARGETS)
	@echo "✓ Clean complete"

install: all
	@echo "Setting executable permissions..."
	@chmod +x $(ALL_TARGETS)
	@echo "✓ All binaries are now executable"

info:
	@echo "========================================"
	@echo "tmux-powerkit Build Configuration"
	@echo "========================================"
	@echo "Compiler:     $(CC)"
	@echo "Architecture: $(ARCH)"
	@echo "Flags:        $(CFLAGS)"
	@echo "Targets:      $(ALL_TARGETS)"
	@echo "========================================"

help:
	@echo "Available targets:"
	@echo "  all       - Build all helpers (default)"
	@echo "  clean     - Remove build artifacts"
	@echo "  install   - Make binaries executable"
	@echo "  info      - Show build configuration"
	@echo "  help      - Show this help message"
	@echo ""
	@echo "Individual targets:"
	@echo "  $(BRIGHTNESS)"
	@echo "  $(NOWPLAYING)"
	@echo "  $(TEMPERATURE)"
	@echo "  $(GPU)"
	@echo "  $(MICROPHONE)"
	@echo ""
	@echo "Environment variables:"
	@echo "  ARCH       - Target architecture (default: current)"
	@echo "  VERSION    - Version string"
	@echo "  COMMIT     - Git commit hash"
	@echo "  BUILD_DATE - Build timestamp"