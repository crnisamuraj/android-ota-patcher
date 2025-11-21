#!/bin/bash
##
# entrypoint.sh - Container entrypoint for Android OTA Patcher
#
# This script acts as a CLI interface for the containerized OTA patcher,
# routing commands to appropriate scripts based on the operation requested.
#

set -e

SCRIPT_DIR="/workspace"
DATA_DIR="${DATA_DIR:-/data}"
export DATA_DIR

# Ensure data directory exists and is writable
mkdir -p "$DATA_DIR"

# Fix permissions for the mounted data directory
# This handles the case where host UID != container UID
if [ -d "$DATA_DIR" ]; then
    echo "🔧 Fixing permissions for $DATA_DIR..."
    # Make sure the directory is accessible and writable
    chmod -R 755 "$DATA_DIR" 2>/dev/null || true
    # Ensure the directory is writable
    chmod 777 "$DATA_DIR" 2>/dev/null || true
    echo "✅ Permissions fixed for $DATA_DIR"
fi

cd "$SCRIPT_DIR"

# Function to show help
show_help() {
    cat << EOF
Android OTA Patcher Container - CLI Interface

USAGE:
    docker run [options] android-ota-patcher COMMAND [args...]

COMMANDS:
    scrape          Scrape latest OTA URL for a device
    download        Download latest OTA for a device  
    patch           Patch an OTA zip file
    ci              Run CI pipeline (check, download, patch if new)
    boot-patch      Extract and patch boot image with custom kernel
    sideload        Sideload a patched OTA to connected device
    setup-chrome    Auto-configure Chrome binary path
    devices         List configured devices from devices.yaml
    shell           Start interactive shell in container

SCRAPE EXAMPLES:
    # Get latest OTA URL for Pixel 7 Pro
    docker run --rm android-ota-patcher scrape --device cheetah

    # Get OTA URL with debug output
    docker run --rm android-ota-patcher scrape --device cheetah --debug

DOWNLOAD EXAMPLES:
    # Download latest OTA for Pixel 7 Pro
    docker run --rm -v /host/data:/data android-ota-patcher download --device cheetah

    # Download to specific output directory
    docker run --rm -v /host/data:/data android-ota-patcher download --device cheetah --output-dir /data/pixel7pro

PATCH EXAMPLES:
    # Patch with Magisk (requires keys and Magisk APK)
    docker run --rm -v /host/data:/data -v /host/keys:/workspace/keys android-ota-patcher patch \\
        --ota /data/ota.zip --mode magisk --magisk-preinit-device /dev/block/by-name/preinit

    # Patch with prepatched boot image  
    docker run --rm -v /host/data:/data -v /host/keys:/workspace/keys android-ota-patcher patch \\
        --ota /data/ota.zip --mode prepatched --prepatched /data/new-boot.img

    # Rootless patch
    docker run --rm -v /host/data:/data -v /host/keys:/workspace/keys android-ota-patcher patch \\
        --ota /data/ota.zip --mode rootless

CI EXAMPLES:
    # Run full CI pipeline for default device (cheetah)
    docker run --rm -v /host/data:/data -v /host/keys:/workspace/keys android-ota-patcher ci

    # Run for multiple devices
    docker run --rm -v /host/data:/data -v /host/keys:/workspace/keys android-ota-patcher ci \\
        --devices "cheetah:cheetah pixel8:shiba"

BOOT PATCH EXAMPLES:
    # Patch boot image with custom kernel
    docker run --rm -v /host/data:/data android-ota-patcher boot-patch \\
        /data/ota.zip /data/custom-kernel.zip

SIDELOAD EXAMPLES:
    # Sideload patched OTA (requires USB device access)
    docker run --rm -v /host/data:/data --privileged -v /dev/bus/usb:/dev/bus/usb android-ota-patcher \\
        sideload /data/ota.zip.patched

VOLUME MOUNTS:
    /data           - Working directory for downloads and output files
    /workspace/keys - Directory containing signing keys (avb.key, ota.key, ota.crt)

REQUIRED FILES (mount to /workspace/keys/):
    avb.key         - AVB signing private key
    ota.key         - OTA signing private key  
    ota.crt         - OTA signing certificate
    Magisk-v29.0.apk - Magisk APK (for Magisk patching mode)

ENVIRONMENT VARIABLES:
    DATA_DIR        - Data directory path (default: /data)
    DEVICES         - Default devices list for CI mode
    DEBUG           - Enable debug output (1/0)

EOF
}

# Function to setup working environment
setup_environment() {
    # Ensure keys exist or warn user
    if [[ ! -f "/workspace/keys/avb.key" ]] || [[ ! -f "/workspace/keys/ota.key" ]] || [[ ! -f "/workspace/keys/ota.crt" ]]; then
        echo "⚠️  Warning: Signing keys not found in /workspace/keys/"
        echo "   Mount your keys directory: -v /path/to/keys:/workspace/keys"
        echo "   Required files: avb.key, ota.key, ota.crt"
    fi
    
    # Copy keys to workspace if they exist
    if [[ -d "/workspace/keys" ]] && [[ -f "/workspace/keys/avb.key" ]]; then
        cp /workspace/keys/avb.key . 2>/dev/null || true
        cp /workspace/keys/ota.key . 2>/dev/null || true  
        cp /workspace/keys/ota.crt . 2>/dev/null || true
        cp /workspace/keys/Magisk-v29.0.apk . 2>/dev/null || true
        echo "✅ Signing keys copied from /workspace/keys/"
    elif [[ -n "$PASSPHRASE_OTA" ]] || [[ -n "$PASSPHRASE_AVB" ]]; then
        echo "⚠️  Warning: Passphrases provided but no signing keys found in /workspace/keys/"
        echo "   Expected files: avb.key, ota.key, ota.crt"
        echo "   Mount your keys directory: -v /path/to/your/keys:/workspace/keys"
    fi

    # Set up data directory with proper error handling
    if [[ -d "$DATA_DIR" ]]; then
        # Try to create devices directory, handle permission errors gracefully
        if ! mkdir -p "$DATA_DIR/devices" 2>/dev/null; then
            echo "⚠️  Warning: Cannot create $DATA_DIR/devices - using workspace directory"
            DATA_DIR="/workspace"
            mkdir -p "$DATA_DIR/devices" 2>/dev/null || true
        fi
        
        # Link devices directory if not already linked
        if [[ ! -L "devices" ]] && [[ ! -d "devices" ]]; then
            if ln -sf "$DATA_DIR/devices" devices 2>/dev/null; then
                echo "✅ Linked devices directory to $DATA_DIR/devices"
            else
                echo "⚠️  Warning: Cannot create symlink, using local devices directory"
                mkdir -p devices 2>/dev/null || true
            fi
        fi
    else
        echo "⚠️  Warning: Data directory $DATA_DIR not accessible, using workspace"
        mkdir -p devices 2>/dev/null || true
    fi
}

# Function to run scrape command
cmd_scrape() {
    shift # remove 'scrape' from args
    echo "🔍 Scraping OTA information..."
    # Use the container's pre-configured Python environment
    python3 scrape_ota_selenium.py --no-download "$@"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "❌ Scraping failed with exit code $exit_code" >&2
        exit $exit_code
    fi
}

# Function to run download command
cmd_download() {
    shift # remove 'download' from args
    
    # Parse arguments to get device and output directory
    DEVICE=""
    OUTPUT_DIR=""
    ARGS=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --device)
                shift; DEVICE="$1";;
            --output-dir)
                shift; OUTPUT_DIR="$1";;
            *)
                ARGS+=("$1");;
        esac
        shift
    done
    
    # Default to device-specific directory if not specified
    if [ -z "$OUTPUT_DIR" ] && [ -n "$DEVICE" ]; then
        OUTPUT_DIR="$DATA_DIR/devices/$DEVICE"
    fi
    
    if [[ -z "$DEVICE" ]]; then
        echo "❌ Error: --device <codename> is required"
        exit 1
    fi
    
    echo "📥 Downloading latest OTA for device: $DEVICE"
    mkdir -p "$OUTPUT_DIR"
    ./run_ota_scraper.sh --device "$DEVICE" --output-dir "$OUTPUT_DIR" "${ARGS[@]}"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "❌ Download failed with exit code $exit_code" >&2
        exit $exit_code
    fi
}

# Function to run patch command  
cmd_patch() {
    shift # remove 'patch' from args
    echo "🔧 Patching OTA..."
    ./patch-ota.sh "$@"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "❌ Patching failed with exit code $exit_code" >&2
        exit $exit_code
    fi
}

# Function to run CI pipeline
cmd_ci() {
    shift # remove 'ci' from args
    echo "🚀 Running CI pipeline..."
    ./ci_ota_patch.sh "$@"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "❌ CI pipeline failed with exit code $exit_code" >&2
        exit $exit_code
    fi
}

# Function to run boot patch
cmd_boot_patch() {
    shift # remove 'boot-patch' from args
    if [[ $# -lt 2 ]]; then
        echo "❌ Usage: boot-patch <ota_zip> <patched_kernel_zip> [workdir]"
        exit 1
    fi
    echo "🥾 Patching boot image..."
    exec ./patch-boot.sh "$@"
}

# Function to run sideload
cmd_sideload() {
    shift # remove 'sideload' from args
    if [[ $# -lt 1 ]]; then
        echo "❌ Usage: sideload <patched_ota_file>"
        exit 1
    fi
    echo "📱 Sideloading OTA..."
    exec ./sideload.sh "$@"
}

# Function to setup Chrome configuration
cmd_setup_chrome() {
    echo "🌐 Setting up Chrome configuration..."
    exec ./setup_chrome_config.sh
}

# Function to list devices
cmd_devices() {
    shift # remove 'devices' from args
    if [[ -f "devices.yaml" ]]; then
        echo "📱 Configured devices:"
        exec python3 get_devices.py "$@"
    else
        echo "❌ devices.yaml not found"
        exit 1
    fi
}

# Function to start interactive shell
cmd_shell() {
    echo "🐚 Starting interactive shell..."
    exec /bin/bash
}

# Main command routing
main() {
    # Set up environment
    setup_environment
    
    # Handle empty args or help
    if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]] || [[ "$1" == "help" ]]; then
        show_help
        exit 0
    fi
    
    # Route to appropriate command
    case "$1" in
        "scrape")
            cmd_scrape "$@"
            ;;
        "download")  
            cmd_download "$@"
            ;;
        "patch")
            cmd_patch "$@"
            ;;
        "ci")
            cmd_ci "$@"
            ;;
        "boot-patch")
            cmd_boot_patch "$@"
            ;;
        "sideload")
            cmd_sideload "$@"
            ;;
        "setup-chrome")
            cmd_setup_chrome "$@"
            ;;
        "devices")
            cmd_devices "$@"
            ;;
        "shell")
            cmd_shell "$@"
            ;;
        *)
            echo "❌ Unknown command: $1"
            echo "Run with --help to see available commands"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
