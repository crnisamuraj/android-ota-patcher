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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_SCRIPT="$SCRIPT_DIR/patch-ota.sh"

HARDCODED_DEVICES="cheetah:cheetah"

# Accept --devices arg, else use DEVICES env, else fallback
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
    DEVICES="$HARDCODED_DEVICES"
fi



for entry in $DEVICES; do
    FOLDER="${entry%%:*}"
    CODENAME="${entry##*:}"
    DEVICE_DIR="$SCRIPT_DIR/devices/$FOLDER"
    OTA_URL_FILE="$DEVICE_DIR/current_ota_url.txt"
    LAST_URL_FILE="$DEVICE_DIR/last_ota_url.txt"
    OTA_ZIP="$DEVICE_DIR/ota.zip"

    mkdir -p "$DEVICE_DIR"

    # Fetch latest OTA URL for this device using run_ota_scraper.sh
    bash "$SCRIPT_DIR/run_ota_scraper.sh" --device "$CODENAME" --no-download --silent > "$OTA_URL_FILE"
    OTA_URL=$(cat "$OTA_URL_FILE" | tail -n 1)
    LAST_URL=""
    [ -f "$LAST_URL_FILE" ] && LAST_URL=$(cat "$LAST_URL_FILE")
    echo "DEBUG: OTA_URL for $FOLDER: '$OTA_URL'"
    echo "DEBUG: LAST_URL for $FOLDER: '$LAST_URL'"
    if [ -z "$OTA_URL" ] || [ -z "$LAST_URL" ] || [ "$OTA_URL" != "$LAST_URL" ]; then
        echo "New OTA for $FOLDER: $OTA_URL"
        echo "Downloading OTA zip..."
        wget -O "$OTA_ZIP" "$OTA_URL"
        echo "Patching OTA zip for $FOLDER..."
        if bash "$PATCH_SCRIPT" --ota "$OTA_ZIP" --mode rootless --workdir "$DEVICE_DIR"; then
            echo "$OTA_URL" > "$LAST_URL_FILE"
        else
            echo "Patching failed for $FOLDER, not updating last_ota_url.txt"
        fi
    else
        echo "No new OTA for $FOLDER, skipping patch."
    fi
done
