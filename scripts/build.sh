#!/bin/bash
# =============================================================================
# PowerKit: Build Script for macOS Native Binaries
# Description: Build macOS binaries for release (called by semantic-release)
# Source: src/native/macos/ -> dist/
#
# Usage:
#   scripts/build.sh <suffix>  Build native binaries for target architecture
#   scripts/build.sh --check  Check shell script formatting with shfmt
#   scripts/build.sh --fix    Apply shfmt formatting in place
#   scripts/build.sh -h       Show this help message
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SRC_DIR="${ROOT_DIR}/src/native/macos"
DIST_DIR="${ROOT_DIR}/dist"

# Directories scanned by shfmt (themes excluded - pure data declarations)
SHFMT_DIRS=(
  "${ROOT_DIR}/src/core"
  "${ROOT_DIR}/src/utils"
  "${ROOT_DIR}/src/contract"
  "${ROOT_DIR}/src/renderer"
  "${ROOT_DIR}/src/plugins"
  "${ROOT_DIR}/src/helpers"
  "${ROOT_DIR}/bin"
  "${ROOT_DIR}/scripts"
  "${ROOT_DIR}/tests"
)

# =============================================================================
# Helpers
# =============================================================================

usage() {
  cat << EOF
Usage: scripts/build.sh [options] [<suffix>]

Options:
  --check       Run shfmt check on all shell scripts and exit
  --fix         Run shfmt in write mode on all shell scripts and exit
  -h, --help    Show this help message

Arguments:
  <suffix>      Architecture suffix (e.g. arm64, amd64) for native build

Examples:
  scripts/build.sh arm64
  scripts/build.sh --check
  scripts/build.sh --fix
EOF
}

run_shfmt() {
  local mode="${1:-check}"

  if ! command -v shfmt > /dev/null 2>&1; then
    echo "❌ Error: shfmt not found" >&2
    echo "Install with one of:" >&2
    echo "  brew install shfmt" >&2
    echo "  mise install shfmt" >&2
    echo "  go install mvdan.cc/sh/v3/cmd/shfmt@latest" >&2
    return 1
  fi

  case "$mode" in
    fix)
      echo "=== Running shfmt (fix mode) ==="
      shfmt -w -i 2 -ci -sr -bn "${SHFMT_DIRS[@]}"
      echo "✓ shfmt formatting applied"
      ;;
    check | *)
      echo "=== Running shfmt (check mode) ==="
      if shfmt -d -i 2 -ci -sr -bn "${SHFMT_DIRS[@]}"; then
        echo "✓ All files are properly formatted"
      else
        echo "" >&2
        echo "❌ Some files need formatting. Run with --fix to apply." >&2
        return 1
      fi
      ;;
  esac
}

# =============================================================================
# Argument parsing
# =============================================================================

ACTION=""
SUFFIX=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      ACTION="check"
      shift
      ;;
    --fix)
      ACTION="fix"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      echo "❌ Error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      SUFFIX="$1"
      shift
      ;;
  esac
done

# Dispatch to shfmt action if requested
if [[ -n "$ACTION" ]]; then
  if ! run_shfmt "$ACTION"; then
    exit 1
  fi
  exit 0
fi

# Validate suffix for build action
if [[ -z "$SUFFIX" ]]; then
  echo "❌ Error: SUFFIX argument required for build" >&2
  usage >&2
  exit 1
fi

# =============================================================================
# Original build logic
# =============================================================================

VERSION=${NEXT_RELEASE_VERSION:-"dev"}
COMMIT_SHA=$(git rev-parse --short HEAD 2> /dev/null || echo "unknown")
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
NATIVE_ARCH=$(uname -m)

echo "========================================="
echo "Building tmux-powerkit helpers"
echo "Version: $VERSION"
echo "Commit: $COMMIT_SHA"
echo "Target: $SUFFIX"
echo "Native Architecture: $NATIVE_ARCH"
echo "Date: $BUILD_DATE"
echo "Source: $SRC_DIR"
echo "Output: $DIST_DIR"
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

# Validate source directory exists
if [[ ! -d "$SRC_DIR" ]]; then
  echo "❌ Error: Source directory not found: $SRC_DIR"
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
cd "$SRC_DIR"

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
  # Skip source files
  [[ "$binary" == *.m ]] && continue

  if [ ! -f "$binary" ]; then
    echo "❌ Binary not found: $binary"
    VERIFICATION_FAILED=1
    continue
  fi

  echo ""
  echo "File: $binary"
  ls -lh "$binary"

  # Verify architecture
  if lipo -info "$binary" 2> /dev/null | grep -q "$TARGET_ARCH"; then
    echo "✓ Architecture verified: $TARGET_ARCH"
  else
    echo "❌ Wrong architecture in: $binary"
    lipo -info "$binary" 2> /dev/null
    VERIFICATION_FAILED=1
  fi
done

if [ $VERIFICATION_FAILED -eq 1 ]; then
  echo ""
  echo "❌ Build verification failed"
  exit 1
fi

# Create dist directory
mkdir -p "$DIST_DIR"

# Copy binaries with suffix
echo ""
echo "=== Copying binaries to dist ==="
for binary in powerkit-*; do
  # Skip source files
  [[ "$binary" == *.m ]] && continue
  [[ ! -x "$binary" ]] && continue

  TARGET_NAME="${binary}-${SUFFIX}"
  cp "$binary" "${DIST_DIR}/${TARGET_NAME}"
  chmod +x "${DIST_DIR}/${TARGET_NAME}"
  echo "✓ Copied: ${binary} -> dist/${TARGET_NAME}"
done

# Generate checksums
cd "$DIST_DIR"
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
macOS Version:    $(sw_vers -productVersion 2> /dev/null || echo "N/A")
Xcode Version:    $(xcodebuild -version 2> /dev/null | head -n 1 | cut -d' ' -f2 || echo "N/A")
Clang Version:    $(clang --version 2> /dev/null | head -n 1 | sed 's/.*version //' | cut -d' ' -f1 || echo "N/A")

Binaries Included:
$(for file in *-"${SUFFIX}"; do
  [[ -f "$file" && "$file" != *.txt ]] || continue
  size=$(du -h "$file" | cut -f1)
  echo "  - $file ($size)"
done)

SHA256 Checksums:
$(cat SHA256SUMS-${SUFFIX}.txt | sed 's/^/  /')
EOF

echo ""
echo "=== Build complete ==="
ls -lah *-${SUFFIX}*
