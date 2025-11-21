#!/bin/bash
##
# setup_chrome_config.sh
#
# Description:
#   Auto-detects Chrome installation and creates chrome_paths.conf
#   Prioritizes Flatpak Chrome since that's what the user mentioned they have
#
# Usage:
#   ./setup_chrome_config.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/chrome_paths.conf"

echo "Detecting Chrome installations..."

# Check for Flatpak Chrome first (user's preference)
if [ -x "/var/lib/flatpak/exports/bin/com.google.Chrome" ]; then
    echo "Found Flatpak Google Chrome at /var/lib/flatpak/exports/bin/com.google.Chrome"
    sed -i 's|^# CHROME_BINARY=/var/lib/flatpak/exports/bin/com.google.Chrome|CHROME_BINARY=/var/lib/flatpak/exports/bin/com.google.Chrome|' "$CONFIG_FILE"
    echo "Configured chrome_paths.conf to use Flatpak Google Chrome"
    exit 0
fi

# Check for Flatpak Chromium
if [ -x "/var/lib/flatpak/exports/bin/org.chromium.Chromium" ]; then
    echo "Found Flatpak Chromium at /var/lib/flatpak/exports/bin/org.chromium.Chromium"
    sed -i 's|^# CHROME_BINARY=/var/lib/flatpak/exports/bin/org.chromium.Chromium|CHROME_BINARY=/var/lib/flatpak/exports/bin/org.chromium.Chromium|' "$CONFIG_FILE"
    echo "Configured chrome_paths.conf to use Flatpak Chromium"
    exit 0
fi

# Check for native installations
if command -v google-chrome >/dev/null 2>&1; then
    CHROME_PATH=$(command -v google-chrome)
    echo "Found native Google Chrome at $CHROME_PATH"
    sed -i "s|^# CHROME_BINARY=/usr/bin/google-chrome|CHROME_BINARY=$CHROME_PATH|" "$CONFIG_FILE"
    echo "Configured chrome_paths.conf to use native Google Chrome"
    exit 0
fi

if command -v google-chrome-stable >/dev/null 2>&1; then
    CHROME_PATH=$(command -v google-chrome-stable)
    echo "Found Google Chrome Stable at $CHROME_PATH"
    sed -i "s|^# CHROME_BINARY=/usr/bin/google-chrome-stable|CHROME_BINARY=$CHROME_PATH|" "$CONFIG_FILE"
    echo "Configured chrome_paths.conf to use Google Chrome Stable"
    exit 0
fi

if command -v chromium-browser >/dev/null 2>&1; then
    CHROME_PATH=$(command -v chromium-browser)
    echo "Found Chromium at $CHROME_PATH"
    sed -i "s|^# CHROME_BINARY=/usr/bin/chromium-browser|CHROME_BINARY=$CHROME_PATH|" "$CONFIG_FILE"
    echo "Configured chrome_paths.conf to use Chromium"
    exit 0
fi

echo "No Chrome installation detected. Please manually edit chrome_paths.conf"
echo "Available configuration file: $CONFIG_FILE"
exit 1
