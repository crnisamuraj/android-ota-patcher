#!/bin/bash


#
# ci_ota_patch.sh
#
# Description:
#   This script automates OTA update checking and patching for Google Pixel devices, intended for CI/CD or local use.
#   For each device, it fetches the latest OTA URL using run_ota_scraper.sh, compares it to the last processed URL, and if new, downloads and patches the OTA zip using patch-ota.sh in rootless mode.
#   Device OTA URLs and state are managed in the devices/<device>/ directory.
#
# Usage:
#   ./ci_ota_patch.sh [--devices <list>]
#
# Arguments:
#   --devices <list>   Space-separated list of device:codename pairs (e.g., cheetah:cheetah pixel7pro:cheetah)
#                      Can also be set via DEVICES env var. Defaults to cheetah:cheetah if not set.
#
# Requirements:
#   - wget
#   - patch-ota.sh and run_ota_scraper.sh in the same directory
#   - run_ota_scraper.sh must support --device <codename> and --no-download
#
# Output:
#   - Downloads new OTA zips to devices/<device>/ota.zip
#   - Patches OTA zips in place using patch-ota.sh (rootless mode)
#   - Updates devices/<device>/last_ota_url.txt after successful patch
#
# Example:
#   ./ci_ota_patch.sh --devices cheetah:cheetah pixel7pro:cheetah
#   DEVICES="cheetah:cheetah pixel8:shiba" ./ci_ota_patch.sh
#

# For each device, fetch the latest OTA URL, compare, and patch if needed

# This script is intended to be called from CI/CD (GitLab CI, GitHub Actions, or locally)
# It will:
# 1. Set DEVICES from argument, env, or fallback
# 2. Run the OTA scraper (silent, no download, just check for new)
# 3. For each device, if a new OTA zip was found, download and patch it
set -e

# Enable error reporting and exit on failure
trap 'echo "❌ CI pipeline failed at line $LINENO with exit code $?" >&2; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_SCRIPT="$SCRIPT_DIR/patch-ota.sh"

# Default devices from devices.yaml or fallback
get_default_devices() {
    local devices_file="$SCRIPT_DIR/devices.yaml"
    local devices_list=""
    
    if [ -f "$devices_file" ]; then
        # Simple parsing of devices.yaml (folder and codename)
        # Looks for: folder: <value> and codename: <value>
        # Assumes consistent ordering or simple structure
        while IFS= read -r line; do
            if [[ $line =~ folder:[[:space:]]*(.*) ]]; then
                current_folder="${BASH_REMATCH[1]}"
            elif [[ $line =~ codename:[[:space:]]*(.*) ]]; then
                current_codename="${BASH_REMATCH[1]}"
                if [ -n "$current_folder" ] && [ -n "$current_codename" ]; then
                    devices_list="$devices_list $current_folder:$current_codename"
                    current_folder=""
                    current_codename=""
                fi
            fi
        done < "$devices_file"
    fi
    
    # Trim leading space
    echo "${devices_list#" "}"
}

HARDCODED_DEVICES="cheetah:cheetah"

# Accept --devices arg, else use DEVICES env, else parse devices.yaml, else fallback
DEVICES_ARG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --devices=*) DEVICES_ARG="${1#--devices=}"; shift;;
        --devices) shift; DEVICES_ARG="$1"; shift;;
        *) shift;;
    esac
    break
 done

if [ -n "$DEVICES_ARG" ]; then
    DEVICES="$DEVICES_ARG"
elif [ -n "$DEVICES" ]; then
    :
else
    DETECTED_DEVICES=$(get_default_devices)
    if [ -n "$DETECTED_DEVICES" ]; then
        DEVICES="$DETECTED_DEVICES"
        echo "📋 Loaded devices from devices.yaml: $DEVICES"
    else
        DEVICES="$HARDCODED_DEVICES"
        echo "⚠️  Could not load devices.yaml, using fallback: $DEVICES"
    fi
fi



for entry in $DEVICES; do
    FOLDER="${entry%%:*}"
    CODENAME="${entry##*:}"
    # Use DATA_DIR if available (container environment), otherwise use local devices
    if [ -n "${DATA_DIR:-}" ] && [ -d "${DATA_DIR}" ]; then
        DEVICE_DIR="$DATA_DIR/devices/$CODENAME"
    else
        DEVICE_DIR="$SCRIPT_DIR/devices/$CODENAME"
    fi
    OTA_URL_FILE="$DEVICE_DIR/current_ota_url.txt"
    LAST_URL_FILE="$DEVICE_DIR/last_ota_url.txt"
    OTA_ZIP="$DEVICE_DIR/ota.zip"

    echo "📱 Processing device: $FOLDER ($CODENAME)"
    echo "📂 Device directory: $DEVICE_DIR"
    echo "🗂️  Data directory: ${DATA_DIR:-'not set'}"
    mkdir -p "$DEVICE_DIR"

    # Fetch latest OTA URL for this device
    echo "🔍 Fetching latest OTA URL for $FOLDER..."
    
    # Check if we're running in a container environment (has .venv directory)
    if [ -d "$SCRIPT_DIR/.venv" ]; then
        # Running in container - use Python script directly
        if ! python3 "$SCRIPT_DIR/scrape_ota_selenium.py" --device "$CODENAME" --no-download > "$OTA_URL_FILE" 2>/dev/null; then
            echo "❌ Failed to fetch OTA URL for $CODENAME using direct Python call" >&2
            continue
        fi
    else
        # Running on host - use wrapper script
        if ! bash "$SCRIPT_DIR/run_ota_scraper.sh" --device "$CODENAME" --no-download --silent > "$OTA_URL_FILE"; then
            echo "❌ Failed to fetch OTA URL for $CODENAME using run_ota_scraper.sh" >&2
            continue
        fi
    fi
    
    OTA_URL=$(cat "$OTA_URL_FILE" | tail -n 1)
    LAST_URL=""
    [ -f "$LAST_URL_FILE" ] && LAST_URL=$(cat "$LAST_URL_FILE")
    
    echo "🔗 Current OTA URL for $CODENAME: '$OTA_URL'"
    echo "📝 Last processed URL for $CODENAME: '$LAST_URL'"
    
    if [ -z "$OTA_URL" ]; then
        echo "❌ ERROR: Empty OTA URL for $CODENAME" >&2
        continue
    fi
    
    if [ -z "$LAST_URL" ] || [ "$OTA_URL" != "$LAST_URL" ]; then
        echo "✅ New OTA detected for $CODENAME: $OTA_URL"
        
        # Extract filename from URL for better organization
        OTA_FILENAME=$(basename "$OTA_URL")
        OTA_ZIP_NAMED="$DEVICE_DIR/$OTA_FILENAME"
        
        echo "📥 Downloading OTA zip to: $OTA_ZIP_NAMED"
        # Use wget with progress bar
        if ! wget --progress=bar:force:noscroll -O "$OTA_ZIP_NAMED" "$OTA_URL"; then
            echo "❌ Failed to download OTA for $CODENAME" >&2
            continue
        fi
        
        # Create a symlink for compatibility with existing scripts
        ln -sf "$OTA_FILENAME" "$OTA_ZIP"
        
        echo "🔧 Patching OTA zip for $CODENAME..."
        if bash "$PATCH_SCRIPT" --ota "$OTA_ZIP" --mode rootless --workdir "$DEVICE_DIR"; then
            echo "$OTA_URL" > "$LAST_URL_FILE"
            echo "✅ Successfully processed $CODENAME"
            echo "💾 Files preserved in: $DEVICE_DIR"
        else
            echo "❌ Patching failed for $CODENAME, not updating last_ota_url.txt" >&2
        fi
    else
        echo "⏭️  No new OTA for $CODENAME, skipping patch."
        echo "📂 Existing files in: $DEVICE_DIR"
    fi
done

echo "🏁 CI pipeline completed for all devices"
