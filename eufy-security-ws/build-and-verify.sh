#!/bin/bash
# Bash script to build Docker container and verify it uses your GitHub fork
# Usage: ./build-and-verify.sh

set -e

EUFY_SECURITY_WS_VERSION="${1:-1.9.3}"
BUILD_FROM="${2:-homeassistant/amd64-base:latest}"
IMAGE_NAME="${3:-test-eufy-ws}"

echo "=========================================="
echo "Building Docker Image"
echo "=========================================="
echo ""

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "Build arguments:"
echo "  BUILD_FROM: $BUILD_FROM"
echo "  EUFY_SECURITY_WS_VERSION: $EUFY_SECURITY_WS_VERSION"
echo "  Image name: $IMAGE_NAME"
echo ""

# Build the Docker image
echo "Building Docker image (this may take a while)..."
if docker build --no-cache \
    --build-arg BUILD_FROM="$BUILD_FROM" \
    --build-arg EUFY_SECURITY_WS_VERSION="$EUFY_SECURITY_WS_VERSION" \
    -t "$IMAGE_NAME" . 2>&1 | tee build.log; then
    echo ""
    echo "✓ Build completed successfully"
else
    echo ""
    echo "✗ BUILD FAILED!"
    exit 1
fi

echo ""
echo "Build log saved to: build.log"
echo ""

echo "=========================================="
echo "Verifying GitHub Fork Usage"
echo "=========================================="
echo ""

# Check build logs
echo "1. Checking build logs for GitHub fork reference..."
if grep -qi "melsawy93" build.log; then
    echo "   ✓ Found melsawy93 in build logs"
    grep -i "melsawy93" build.log | head -3 | sed 's/^/     /'
else
    echo "   ✗ WARNING: melsawy93 not found in build logs"
fi
echo ""

# Create temporary container
echo "2. Creating temporary container for inspection..."
CONTAINER_ID=$(docker create "$IMAGE_NAME")
echo "   ✓ Container created: $CONTAINER_ID"
echo ""

# Check package.json
echo "3. Checking package.json for GitHub reference..."
PACKAGE_JSON_PATH="/tmp/eufy-package.json"
if docker cp "${CONTAINER_ID}:/usr/src/app/node_modules/eufy-security-client/package.json" "$PACKAGE_JSON_PATH" 2>/dev/null; then
    if grep -q "melsawy93" "$PACKAGE_JSON_PATH"; then
        echo "   ✓ package.json references melsawy93 fork"
        echo "     Repository/Resolved info:"
        grep -E '"repository"|"_resolved"' "$PACKAGE_JSON_PATH" | head -2 | sed 's/^/       /'
    else
        echo "   ✗ WARNING: package.json does NOT reference melsawy93 fork"
        echo "     Showing relevant lines:"
        grep -E '"repository"|"_resolved"' "$PACKAGE_JSON_PATH" | head -2 | sed 's/^/       /'
    fi
else
    echo "   ✗ Could not extract package.json"
fi
echo ""

# Check if your code is present
echo "4. Checking if your code changes are present..."
SESSION_JS_PATH="/tmp/session.js"
if docker cp "${CONTAINER_ID}:/usr/src/app/node_modules/eufy-security-client/build/p2p/session.js" "$SESSION_JS_PATH" 2>/dev/null; then
    # Check for debug markers
    ALL_FOUND=true
    
    if grep -q "T85D0_DEBUG_v2" "$SESSION_JS_PATH"; then
        echo "   ✓ Found marker: T85D0_DEBUG_v2"
    else
        echo "   ✗ Missing marker: T85D0_DEBUG_v2"
        ALL_FOUND=false
    fi
    
    if grep -q "Get DSK keys v2" "$SESSION_JS_PATH"; then
        echo "   ✓ Found marker: Get DSK keys v2"
    else
        echo "   ✗ Missing marker: Get DSK keys v2"
        ALL_FOUND=false
    fi
    
    if grep -q "lockDevice() ENTRY POINT" "$SESSION_JS_PATH"; then
        echo "   ✓ Found marker: lockDevice() ENTRY POINT"
    else
        echo "   ✗ Missing marker: lockDevice() ENTRY POINT"
        ALL_FOUND=false
    fi
    
    if [ "$ALL_FOUND" = true ]; then
        echo ""
        echo "   ✓✓✓ ALL YOUR CODE CHANGES ARE PRESENT! ✓✓✓"
    else
        echo ""
        echo "   ✗✗✗ SOME CODE CHANGES ARE MISSING! ✗✗✗"
    fi
    
    # Show a sample of the code
    echo ""
    echo "   Sample code snippets found:"
    grep "T85D0_DEBUG_v2" "$SESSION_JS_PATH" | head -3 | sed 's/^/     /'
else
    echo "   ✗ Could not extract session.js"
    echo "   Checking if build directory exists..."
    docker exec "$CONTAINER_ID" sh -c "ls -la /usr/src/app/node_modules/eufy-security-client/build/p2p/ 2>&1" 2>&1 || true
fi
echo ""

# Check git commit (if available)
echo "5. Checking git commit info..."
GIT_INFO=$(docker exec "$CONTAINER_ID" sh -c "cd /usr/src/app/node_modules/eufy-security-client && git log -1 --oneline 2>&1" 2>&1 || echo "Not available")
if echo "$GIT_INFO" | grep -qv "Not a git repo\|fatal"; then
    echo "   ✓ Git commit found:"
    echo "     $GIT_INFO" | sed 's/^/     /'
else
    echo "   ⚠ Git info not available (this is normal for npm packages)"
fi
echo ""

# Cleanup
echo "6. Cleaning up..."
docker rm "$CONTAINER_ID" >/dev/null 2>&1
rm -f "$PACKAGE_JSON_PATH" "$SESSION_JS_PATH"
echo "   ✓ Cleanup complete"
echo ""

echo "=========================================="
echo "Verification Complete"
echo "=========================================="
echo ""
echo "To inspect the image manually:"
echo "  docker run --rm -it $IMAGE_NAME sh"
echo ""
echo "To check files in the container:"
echo "  docker run --rm $IMAGE_NAME sh -c 'grep -r \"T85D0_DEBUG_v2\" /usr/src/app/node_modules/eufy-security-client/build/'"
echo ""

