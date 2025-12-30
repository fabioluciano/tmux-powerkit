#!/bin/bash

set -e

SUFFIX=$1
VERSION=${NEXT_RELEASE_VERSION:-"dev"}
COMMIT_SHA=$(git rev-parse --short HEAD)
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
NATIVE_ARCH=$(uname -m)

echo "========================================="
echo "Building tmux-powerkit helpers"
echo "Version: $VERSION"
echo "Commit: $COMMIT_SHA"
echo "Target: $SUFFIX"
echo "Native Architecture: $NATIVE_ARCH"
echo "Date: $BUILD_DATE"
echo "========================================="

# Validate we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "❌ Error: This build script requires macOS"
  exit 1
fi

# Validate clang is available
if ! command -v clang &> /dev/null; then
  echo "❌ Error: clang compiler not found"
  exit 1
fi

# Determine target architecture
TARGET_ARCH=""
if [[ "$SUFFIX" == *"arm64"* ]]; then
  TARGET_ARCH="arm64"
elif [[ "$SUFFIX" == *"amd64"* ]] || [[ "$SUFFIX" == *"x86_64"* ]]; then
  TARGET_ARCH="x86_64"
else
  echo "❌ Error: Cannot determine target architecture from suffix: $SUFFIX"
  exit 1
fi

echo "Target architecture: $TARGET_ARCH"

# Build native helpers
cd bin/macos

echo ""
echo "=== Cleaning previous builds ==="
make clean || true

echo ""
echo "=== Building for $TARGET_ARCH ==="
ARCH=$TARGET_ARCH VERSION=$VERSION COMMIT=$COMMIT_SHA BUILD_DATE=$BUILD_DATE make all

echo ""
echo "=== Making binaries executable ==="
make install

echo ""
echo "=== Verifying builds ==="
VERIFICATION_FAILED=0

for binary in powerkit-*; do
  if [ ! -f "$binary" ]; then
    echo "❌ Binary not found: $binary"
    VERIFICATION_FAILED=1
    continue
  fi
  
  echo ""
  echo "File: $binary"
  ls -lh "$binary"
  
  # Verify architecture
  if lipo -info "$binary" 2>/dev/null | grep -q "$TARGET_ARCH"; then
    echo "✓ Architecture verified: $TARGET_ARCH"
  else
    echo "❌ Wrong architecture in: $binary"
    lipo -info "$binary" 2>/dev/null
    VERIFICATION_FAILED=1
  fi
done

if [ $VERIFICATION_FAILED -eq 1 ]; then
  echo ""
  echo "❌ Build verification failed"
  exit 1
fi

# Create dist directory
mkdir -p ../../dist

# Copy binaries with suffix
echo ""
echo "=== Copying binaries to dist ==="
for binary in powerkit-*; do
  TARGET_NAME="${binary}-${SUFFIX}"
  cp "$binary" "../../dist/${TARGET_NAME}"
  chmod +x "../../dist/${TARGET_NAME}"
  echo "✓ Copied: ${binary} -> dist/${TARGET_NAME}"
done

# Generate checksums
cd ../../dist
echo ""
echo "=== Generating checksums ==="
shasum -a 256 *-${SUFFIX} > "SHA256SUMS-${SUFFIX}.txt"

# Create build info file
echo ""
echo "=== Creating build info ==="
cat > "BUILD-INFO-${SUFFIX}.txt" << EOF
tmux-powerkit Build Information
================================

Version:          ${VERSION}
Commit:           ${COMMIT_SHA}
Architecture:     ${SUFFIX}
Target Arch:      ${TARGET_ARCH}
Native Arch:      ${NATIVE_ARCH}
Build Date:       ${BUILD_DATE}
Builder:          GitHub Actions
macOS Version:    $(sw_vers -productVersion)
Xcode Version:    $(xcodebuild -version | head -n 1 | cut -d' ' -f2)
Clang Version:    $(clang --version | head -n 1 | sed 's/.*version //' | cut -d' ' -f1)

Binaries Included:
$(ls -1 *-${SUFFIX} | grep -v '.txt$' | while read file; do
  size=$(du -h "$file" | cut -f1)
  echo "  - $file ($size)"
done)

SHA256 Checksums:
$(cat SHA256SUMS-${SUFFIX}.txt | sed 's/^/  /')
EOF

echo ""
echo "=== Build complete ==="
ls -lah *-${SUFFIX}*