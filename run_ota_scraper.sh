#!/bin/bash
##
# run_ota_scraper.sh
#
# Description:
#   Prepares a Python virtual environment and runs the OTA scraping Python script for a single device/codename.
#   If --no-download is specified, prints the latest OTA URL to stdout. Otherwise, downloads the OTA zip to the specified directory.
#   Device iteration and file management are handled by the caller (e.g., ci_ota_patch.sh).
#
# Usage:
#   ./run_ota_scraper.sh --device <codename> [--output-dir <dir>] [--no-download] [--silent] [--chrome-binary <path>] [other scrape_ota_selenium.py args]
#
# Arguments:
#   --device <codename>     Device codename to scrape (required)
#   --output-dir <dir>      Directory to download the OTA zip (required if not using --no-download)
#   --no-download           Only print the latest OTA URL, do not download
#   --silent                Suppress output except errors and results (passed to Python script)
#   --chrome-binary <path>  Path to Chrome binary (e.g., /var/lib/flatpak/exports/bin/com.google.Chrome)
#   [other args]            Any other arguments are passed to scrape_ota_selenium.py
#
# Requirements:
#   - Python 3
#   - Selenium and webdriver-manager (installed automatically in venv)
#   - scrape_ota_selenium.py in the same directory
#
# Output:
#   - Prints the latest OTA URL to stdout (with --no-download)
#   - Downloads the OTA zip to <output-dir>/ota.zip (without --no-download)
#
# Example:
#   ./run_ota_scraper.sh --device cheetah --no-download --silent
#   ./run_ota_scraper.sh --device cheetah --output-dir devices/cheetah
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
PYTHON="$VENV_DIR/bin/python"
SCRIPT="$SCRIPT_DIR/scrape_ota_selenium.py"
CONFIG_FILE="$SCRIPT_DIR/chrome_paths.conf"

# Load Chrome binary path from config file if it exists and no --chrome-binary is specified
if [ -f "$CONFIG_FILE" ] && [ -z "${CHROME_BINARY:-}" ]; then
    source "$CONFIG_FILE"
fi


# Create venv if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Activate venv and install requirements
source "$VENV_DIR/bin/activate"

# Install required packages if not already installed
pip install --upgrade pip > /dev/null
pip install selenium webdriver-manager > /dev/null

# Parse arguments
DEVICE=""
OUTPUT_DIR=""
NO_DOWNLOAD=0
CMDLINE_CHROME_BINARY=""
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --device)
            shift; DEVICE="$1";;
        --output-dir)
            shift; OUTPUT_DIR="$1";;
        --no-download)
            NO_DOWNLOAD=1;;
        --chrome-binary)
            shift; CMDLINE_CHROME_BINARY="$1";;
        *)
            ARGS+=("$1");;
    esac
    shift
done

# Use command line chrome binary if provided, otherwise use config file value
if [ -n "$CMDLINE_CHROME_BINARY" ]; then
    CHROME_BINARY="$CMDLINE_CHROME_BINARY"
fi

if [ -z "$DEVICE" ]; then
    echo "Error: --device <codename> is required." >&2
    exit 1
fi

if [ "$NO_DOWNLOAD" -eq 1 ]; then
    # Print latest OTA URL only
    PYTHON_ARGS=("--device" "$DEVICE" "--no-download" "${ARGS[@]}")
    if [ -n "$CHROME_BINARY" ]; then
        PYTHON_ARGS+=("--chrome-binary" "$CHROME_BINARY")
    fi
    $PYTHON "$SCRIPT" "${PYTHON_ARGS[@]}"
else
    if [ -z "$OUTPUT_DIR" ]; then
        # Default to DATA_DIR/devices/<codename> if available, otherwise use SCRIPT_DIR/devices/<codename>
        if [ -n "${DATA_DIR:-}" ] && [ -d "${DATA_DIR}" ]; then
            OUTPUT_DIR="$DATA_DIR/devices/$DEVICE"
        else
            OUTPUT_DIR="$SCRIPT_DIR/devices/$DEVICE"
        fi
    fi
    mkdir -p "$OUTPUT_DIR"
    # Get latest OTA URL
    PYTHON_ARGS=("--device" "$DEVICE" "--no-download" "${ARGS[@]}")
    if [ -n "$CHROME_BINARY" ]; then
        PYTHON_ARGS+=("--chrome-binary" "$CHROME_BINARY")
    fi
    OTA_URL=$($PYTHON "$SCRIPT" "${PYTHON_ARGS[@]}" | tail -n 1)
    if [ -z "$OTA_URL" ]; then
        echo "Error: Could not determine OTA URL for $DEVICE." >&2
        exit 1
    fi
    
    # Extract filename from URL to preserve original name
    OTA_FILENAME=$(basename "$OTA_URL")
    echo "Downloading OTA zip for $DEVICE: $OTA_URL"
    echo "Saving to: $OUTPUT_DIR/$OTA_FILENAME"
    wget --progress=bar:force:noscroll -O "$OUTPUT_DIR/$OTA_FILENAME" "$OTA_URL"
    
    # Create compatibility symlink
    ln -sf "$OTA_FILENAME" "$OUTPUT_DIR/ota.zip"
    echo "$OTA_URL"
fi
