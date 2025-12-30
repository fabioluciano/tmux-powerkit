#!/bin/bash

set -e

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  SUFFIX="darwin-arm64"
elif [ "$ARCH" = "x86_64" ]; then
  SUFFIX="darwin-amd64"
else
  echo "❌ Unsupported architecture: $ARCH"
  exit 1
fi

echo "🧪 Testing binaries for $SUFFIX"
echo ""

BINARIES=(
  "powerkit-brightness"
  "powerkit-nowplaying"
  "powerkit-temperature"
  "powerkit-gpu"
  "powerkit-microphone"
)

FAILED=0

for binary in "${BINARIES[@]}"; do
  BINARY_PATH="dist/${binary}-${SUFFIX}"
  
  if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ $binary: NOT FOUND"
    FAILED=$((FAILED + 1))
    continue
  fi
  
  if [ ! -x "$BINARY_PATH" ]; then
    echo "⚠️  $binary: NOT EXECUTABLE"
    FAILED=$((FAILED + 1))
    continue
  fi
  
  # Verify architecture
  if lipo -info "$BINARY_PATH" 2>/dev/null | grep -q "$ARCH"; then
    echo "✓ $binary: OK (correct architecture)"
  else
    echo "❌ $binary: WRONG ARCHITECTURE"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
if [ $FAILED -eq 0 ]; then
  echo "✅ All binaries passed tests"
  exit 0
else
  echo "❌ $FAILED binaries failed"
  exit 1
fi