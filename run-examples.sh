#!/bin/bash
##
# run-examples.sh - Example usage scripts for Android OTA Patcher container
#

set -e

CONTAINER_NAME="android-ota-patcher"
CONTAINER_TAG="latest"

echo "🚀 Android OTA Patcher Container Examples"
echo "========================================"

# Check if container exists
if ! (command -v podman >/dev/null 2>&1 && podman images --format "{{.Repository}}:{{.Tag}}" | grep -q "${CONTAINER_NAME}:${CONTAINER_TAG}") && 
   ! (command -v docker >/dev/null 2>&1 && docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${CONTAINER_NAME}:${CONTAINER_TAG}"); then
    echo "❌ Container ${CONTAINER_NAME}:${CONTAINER_TAG} not found"
    echo "   Build it first with: ./build-container.sh"
    exit 1
fi

# Detect container runtime
if command -v podman >/dev/null 2>&1; then
    RUNTIME="podman"
elif command -v docker >/dev/null 2>&1; then
    RUNTIME="docker"
else
    echo "❌ Neither podman nor docker found"
    exit 1
fi

echo "Using: $RUNTIME"
echo ""

# Create example directories
mkdir -p data keys

echo "📋 Example 1: Show help"
echo "Command: $RUNTIME run --rm ${CONTAINER_NAME}:${CONTAINER_TAG}"
$RUNTIME run --rm ${CONTAINER_NAME}:${CONTAINER_TAG}
echo ""

echo "📋 Example 2: List configured devices"  
echo "Command: $RUNTIME run --rm ${CONTAINER_NAME}:${CONTAINER_TAG} devices"
$RUNTIME run --rm ${CONTAINER_NAME}:${CONTAINER_TAG} devices
echo ""

echo "📋 Example 3: Scrape latest OTA URL (Pixel 7 Pro)"
echo "Command: $RUNTIME run --rm ${CONTAINER_NAME}:${CONTAINER_TAG} scrape --device cheetah"
echo "Note: This will take a moment as it launches a browser..."
$RUNTIME run --rm ${CONTAINER_NAME}:${CONTAINER_TAG} scrape --device cheetah
echo ""

echo "📋 Example 4: Download latest OTA (requires data volume)"
echo "Command: $RUNTIME run --rm -v ./data:/data ${CONTAINER_NAME}:${CONTAINER_TAG} download --device cheetah"
echo "Note: Uncomment the line below to actually download (will take time and space)"
# $RUNTIME run --rm -v ./data:/data ${CONTAINER_NAME}:${CONTAINER_TAG} download --device cheetah
echo "[SKIPPED - uncomment to run actual download]"
echo ""

echo "📋 Example 5: Sideload patched OTA (requires USB device)"
echo "Command: docker-compose run --rm ota-sideload"
echo "Note: This requires a connected Android device and /data/ota.zip.patched file"
echo "[SKIPPED - requires physical device and patched OTA file]"
echo ""

echo "📋 Example 6: Interactive shell"
echo "Command: $RUNTIME run --rm -it -v ./data:/data -v ./keys:/workspace/keys ${CONTAINER_NAME}:${CONTAINER_TAG} shell"
echo "Note: This would start an interactive shell in the container"
echo "[SKIPPED - run manually for interactive session]"
echo ""

echo "✅ Examples completed!"
echo ""
echo "🔑 Remember to:"
echo "   1. Put your signing keys in ./keys/ directory"
echo "   2. Use ./data/ directory for downloads and output" 
echo "   3. Check README.md for full usage instructions"
