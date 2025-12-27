# =============================================================================
# Makefile for tmux-powerkit macOS native helpers
# =============================================================================

CC = clang

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

.PHONY: all clean install powerkit-brightness powerkit-nowplaying powerkit-temperature powerkit-gpu powerkit-microphone

all: $(ALL_TARGETS)

$(BRIGHTNESS): $(BRIGHTNESS).m
	$(CC) $(BRIGHTNESS_FRAMEWORKS) $< -o $@

$(NOWPLAYING): $(NOWPLAYING).m
	$(CC) $(NOWPLAYING_FRAMEWORKS) $< -o $@

$(TEMPERATURE): $(TEMPERATURE).m
	$(CC) $(TEMPERATURE_FRAMEWORKS) $< -o $@

$(GPU): $(GPU).m
	$(CC) $(GPU_FRAMEWORKS) $< -o $@

$(MICROPHONE): $(MICROPHONE).m
	$(CC) $(MICROPHONE_FRAMEWORKS) $< -o $@

clean:
	rm -f $(ALL_TARGETS)

install: all
	chmod +x $(ALL_TARGETS)
