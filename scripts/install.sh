#!/bin/bash

set -e

REPO="fabioluciano/tmux-powerkit"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🚀 Installing tmux-powerkit helpers"
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
  echo -e "${RED}❌ This installer only works on macOS${NC}"
  exit 1
fi

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  SUFFIX="darwin-arm64"
  echo "Detected: macOS Apple Silicon (ARM64)"
elif [ "$ARCH" = "x86_64" ]; then
  SUFFIX="darwin-amd64"
  echo "Detected: macOS Intel (AMD64)"
else
  echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"
  exit 1
fi

echo ""

# Find tmux-powerkit installation
echo "🔍 Locating tmux-powerkit installation..."
echo ""

INSTALL_DIR=""

# Check common tmux plugin manager locations
POSSIBLE_LOCATIONS=(
  "$HOME/.tmux/plugins/tmux-powerkit"
  "$HOME/.config/tmux/plugins/tmux-powerkit"
  "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/plugins/tmux-powerkit"
)

for location in "${POSSIBLE_LOCATIONS[@]}"; do
  if [ -d "$location" ]; then
    INSTALL_DIR="$location/bin/macos"
    echo -e "${GREEN}✓ Found tmux-powerkit at: $location${NC}"
    break
  fi
done

# If not found, ask user
if [ -z "$INSTALL_DIR" ]; then
  echo -e "${YELLOW}⚠️  Could not auto-detect tmux-powerkit location${NC}"
  echo ""
  echo "Please enter the path to your tmux-powerkit installation:"
  echo "Example: $HOME/.tmux/plugins/tmux-powerkit"
  echo ""
  read -p "Path: " USER_PATH
  
  if [ -d "$USER_PATH" ]; then
    INSTALL_DIR="$USER_PATH/bin/macos"
  else
    echo -e "${RED}❌ Directory not found: $USER_PATH${NC}"
    exit 1
  fi
fi

# Create bin/macos directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
  echo ""
  echo "📁 Creating directory: $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
fi

echo ""
echo -e "${BLUE}Installing to: $INSTALL_DIR${NC}"
echo ""

BASE_URL="https://github.com/${REPO}/releases/latest/download"

BINARIES=(
  "powerkit-brightness"
  "powerkit-nowplaying"
  "powerkit-temperature"
  "powerkit-gpu"
  "powerkit-microphone"
)

# Create temporary directory
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

echo "📥 Downloading binaries..."
echo ""

# Download binaries
for binary in "${BINARIES[@]}"; do
  FILE="${binary}-${SUFFIX}"
  echo -n "  - ${binary}... "
  if curl -fsSL "${BASE_URL}/${FILE}" -o "${binary}"; then
    echo -e "${GREEN}✓${NC}"
  else
    echo -e "${RED}✗${NC}"
    echo -e "${RED}Failed to download ${FILE}${NC}"
    rm -rf "$TMP_DIR"
    exit 1
  fi
done

echo ""
echo "📥 Downloading checksums..."
if curl -fsSL "${BASE_URL}/SHA256SUMS-${SUFFIX}.txt" -o "SHA256SUMS.txt" 2>/dev/null; then
  echo ""
  echo "🔐 Verifying checksums..."
  if shasum -a 256 -c SHA256SUMS.txt 2>/dev/null; then
    echo -e "${GREEN}✓ All checksums verified${NC}"
  else
    echo -e "${YELLOW}⚠️  Checksum verification failed, but continuing...${NC}"
  fi
else
  echo -e "${YELLOW}⚠️  Could not download checksums, skipping verification${NC}"
fi

echo ""
echo "🔧 Installing binaries..."

# Make executable
chmod +x powerkit-*

# Install
for binary in powerkit-*; do
  if [ -f "$binary" ]; then
    cp "$binary" "$INSTALL_DIR/"
    echo -e "  ${GREEN}✓${NC} Installed: $binary"
  fi
done

# Cleanup
cd /
rm -rf "$TMP_DIR"

echo ""
echo -e "${GREEN}🎉 tmux-powerkit helpers installed successfully!${NC}"
echo ""
echo "Installation directory:"
echo -e "  ${BLUE}$INSTALL_DIR${NC}"
echo ""
echo "Installed binaries:"
for binary in "${BINARIES[@]}"; do
  echo "  - ${INSTALL_DIR}/${binary}"
done
echo ""
echo "💡 Tip: Make sure your tmux configuration uses these helpers!"
echo "   The helpers should be automatically detected by tmux-powerkit."