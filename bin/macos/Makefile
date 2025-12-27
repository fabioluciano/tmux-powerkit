# =============================================================================
# Makefile for tmux-powerkit macOS native helpers
# =============================================================================

CC = clang

# Framework sets for different helpers
BRIGHTNESS_FRAMEWORKS = -framework Foundation -framework IOKit -framework ApplicationServices \
                        -F /System/Library/PrivateFrameworks -framework DisplayServices

NOWPLAYING_FRAMEWORKS = -framework Foundation -framework AppKit -framework ScriptingBridge

# Targets
BRIGHTNESS = powerkit-brightness
NOWPLAYING = powerkit-nowplaying

ALL_TARGETS = $(BRIGHTNESS) $(NOWPLAYING)

.PHONY: all clean install

all: $(ALL_TARGETS)

$(BRIGHTNESS): $(BRIGHTNESS).m
	$(CC) $(BRIGHTNESS_FRAMEWORKS) $< -o $@

$(NOWPLAYING): $(NOWPLAYING).m
	$(CC) $(NOWPLAYING_FRAMEWORKS) $< -o $@

clean:
	rm -f $(ALL_TARGETS)

install: all
	chmod +x $(ALL_TARGETS)
