# =============================================================================
# Makefile for tmux-powerkit macOS native helpers
# =============================================================================

CC = clang
FRAMEWORKS = -framework Foundation -framework IOKit -framework ApplicationServices
PRIVATE_FRAMEWORKS = -F /System/Library/PrivateFrameworks -framework DisplayServices

# Targets
BRIGHTNESS = powerkit-brightness

.PHONY: all clean install

all: $(BRIGHTNESS)

$(BRIGHTNESS): $(BRIGHTNESS).m
	$(CC) $(FRAMEWORKS) $(PRIVATE_FRAMEWORKS) $< -o $@

clean:
	rm -f $(BRIGHTNESS)

install: all
	chmod +x $(BRIGHTNESS)
