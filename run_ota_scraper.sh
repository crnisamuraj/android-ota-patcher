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
#   ./run_ota_scraper.sh --device <codename> [--output-dir <dir>] [--no-download] [--silent] [other scrape_ota_selenium.py args]
#
# Arguments:
#   --device <codename>     Device codename to scrape (required)
#   --output-dir <dir>      Directory to download the OTA zip (required if not using --no-download)
#   --no-download           Only print the latest OTA URL, do not download
#   --silent                Suppress output except errors and results (passed to Python script)
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
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --device)
            shift; DEVICE="$1";;
        --output-dir)
            shift; OUTPUT_DIR="$1";;
        --no-download)
            NO_DOWNLOAD=1;;
        *)
            ARGS+=("$1");;
    esac
    shift
done

if [ -z "$DEVICE" ]; then
    echo "Error: --device <codename> is required." >&2
    exit 1
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

if [ "$NO_DOWNLOAD" -eq 1 ]; then
    # Print latest OTA URL only
    $PYTHON "$SCRIPT" --device "$DEVICE" --no-download "${ARGS[@]}"
else
    if [ -z "$OUTPUT_DIR" ]; then
        echo "Error: --output-dir <dir> is required when downloading." >&2
        exit 1
    fi
    mkdir -p "$OUTPUT_DIR"
    # Get latest OTA URL
    OTA_URL=$($PYTHON "$SCRIPT" --device "$DEVICE" --no-download "${ARGS[@]}" | tail -n 1)
    if [ -z "$OTA_URL" ]; then
        echo "Error: Could not determine OTA URL for $DEVICE." >&2
        exit 1
    fi
    echo "Downloading OTA zip for $DEVICE: $OTA_URL"
    wget -O "$OUTPUT_DIR/ota.zip" "$OTA_URL"
    echo "$OTA_URL"
fi
