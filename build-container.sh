#!/bin/bash
##
# build-container.sh - Build script for Android OTA Patcher container
#

set -e

CONTAINER_NAME="android-ota-patcher"
CONTAINER_TAG="${CONTAINER_TAG:-latest}"
BUILD_ARGS=""

# Check if we're building for different architecture
if [[ -n "${TARGET_ARCH}" ]]; then
    BUILD_ARGS="--platform linux/${TARGET_ARCH}"
fi

# Build container
echo "🔨 Building Android OTA Patcher container..."
echo "Container: ${CONTAINER_NAME}:${CONTAINER_TAG}"

if command -v podman >/dev/null 2>&1; then
    echo "Using Podman..."
    podman build ${BUILD_ARGS} -t "${CONTAINER_NAME}:${CONTAINER_TAG}" -f Containerfile .
elif command -v docker >/dev/null 2>&1; then
    echo "Using Docker..."
    docker build ${BUILD_ARGS} -t "${CONTAINER_NAME}:${CONTAINER_TAG}" -f Containerfile .
else
    echo "❌ Error: Neither podman nor docker found"
    exit 1
fi

echo "✅ Container built successfully!"
echo ""
echo "Usage examples:"
echo "  # Show help"
echo "  podman run --rm ${CONTAINER_NAME}:${CONTAINER_TAG}"
echo ""  
echo "  # Scrape latest OTA URL"
echo "  podman run --rm ${CONTAINER_NAME}:${CONTAINER_TAG} scrape --device cheetah"
echo ""
echo "  # Download and patch with volumes"
echo "  podman run --rm \\"
echo "    -v ./data:/data \\"
echo "    -v ./keys:/workspace/keys \\"  
echo "    ${CONTAINER_NAME}:${CONTAINER_TAG} ci"
