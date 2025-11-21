#!/bin/bash
#
# patch-ota.sh
#
# Description:
#   This script patches a Google Pixel OTA zip using avbroot, supporting Magisk, prepatched, and rootless modes.
#   It signs the OTA with provided keys/certificates and can inject Magisk or use a prepatched boot image.
#   The script also verifies the resulting patched OTA.
#
# Usage:
#   ./patch-ota.sh --ota <path_to_ota_zip> --mode <magisk|prepatched|rootless> [options]
#
# Modes:
#   magisk      - Patch OTA with Magisk (requires --magisk-apk and --magisk-preinit-device)
#   prepatched  - Use a prepatched boot image (requires --prepatched)
#   rootless    - Patch OTA without root (no extra args)
#
# Options:
#   --key-avb <file>             AVB private key (default: ./avb.key)
#   --key-ota <file>             OTA signing key (default: ./ota.key)
#   --cert-ota <file>            OTA certificate (default: ./ota.crt)
#   --magisk-apk <file>          Magisk APK file (required for magisk mode)
#   --magisk-preinit-device <dev> Device for Magisk preinit (required for magisk mode)
#   --prepatched <file>          Prepatched boot image (required for prepatched mode)
#   --workdir <dir>              Working directory (optional)
#   -h, --help                   Show usage
#
# Requirements:
#   - avbroot (must be in PATH)
#
# Environment Variables:
#   - PASSPHRASE_AVB: Passphrase for encrypted AVB signing key
#   - PASSPHRASE_OTA: Passphrase for encrypted OTA signing key
#
# Output:
#   - <ota_zip>.patched (patched OTA zip)
#
# Example:
#   ./patch-ota.sh --ota cheetah-ota-bp2a.250605.031.a2-0662933e.zip --mode magisk --magisk-apk Magisk-v29.0.apk --magisk-preinit-device /dev/block/by-name/preinit
#   ./patch-ota.sh --ota cheetah-ota-bp2a.250605.031.a2-0662933e.zip --mode prepatched --prepatched new-boot.img
#   ./patch-ota.sh --ota cheetah-ota-bp2a.250605.031.a2-0662933e.zip --mode rootless
#
set -e

# Default values
key_avb=${KEY_AVB:-`pwd`/avb.key}
key_ota=${KEY_OTA:-`pwd`/ota.key}
cert_ota=${CERT_OTA:-`pwd`/ota.crt}
mode=""
ota=""
magisk_apk=${MAGISK_APK:-`pwd`/Magisk-v29.0.apk}
magisk_preinit_device=""
prepatched_path=""
workdir="${WORKDIR:-}" # Use WORKDIR env var if set

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ota)
      ota="$2"; shift 2;;
    --mode)
      mode="$2"; shift 2;;
    --key-avb)
      key_avb="$2"; shift 2;;
    --key-ota)
      key_ota="$2"; shift 2;;
    --cert-ota)
      cert_ota="$2"; shift 2;;
    --magisk-apk)
      magisk_apk="$2"; shift 2;;
    --magisk-preinit-device)
      magisk_preinit_device="$2"; shift 2;;
    --prepatched)
      prepatched_path="$2"; shift 2;;
    --workdir)
      workdir="$2"; shift 2;;
    -h|--help)
      echo "Usage: $0 --ota <path_to_ota_zip> --mode <magisk|prepatched|rootless> [--key-avb <file>] [--key-ota <file>] [--cert-ota <file>] [--magisk-apk <file>] [--magisk-preinit-device <dev>] [--prepatched <file>] [--workdir <dir>]"
      exit 0;;
    *)
      echo "Unknown argument: $1"; exit 1;;
  esac
 done

if [ -z "$ota" ] || [ -z "$mode" ]; then
  echo "Usage: $0 --ota <path_to_ota_zip> --mode <magisk|prepatched|rootless> [--key-avb <file>] [--key-ota <file>] [--cert-ota <file>] [--magisk-apk <file>] [--magisk-preinit-device <dev>] [--prepatched <file>] [--workdir <dir>]"
  exit 1
fi

# If workdir is set, change to it and make all paths relative to it
if [ -n "$workdir" ]; then
  mkdir -p "$workdir"
  cd "$workdir"
fi

# Build passphrase arguments for avbroot if environment variables are set
PASSPHRASE_ARGS=()
if [ -n "${PASSPHRASE_AVB:-}" ]; then
    PASSPHRASE_ARGS+=("--pass-avb-env-var" "PASSPHRASE_AVB")
    echo "🔐 Using passphrase for AVB key"
fi
if [ -n "${PASSPHRASE_OTA:-}" ]; then
    PASSPHRASE_ARGS+=("--pass-ota-env-var" "PASSPHRASE_OTA")
    echo "🔐 Using passphrase for OTA key"
fi

echo "🔧 Patching OTA with avbroot (mode: $mode)..."

case "$mode" in
  magisk)
    if [ -z "$magisk_apk" ] || [ -z "$magisk_preinit_device" ]; then
      echo "For magisk mode, --magisk-apk and --magisk-preinit-device are required."
      exit 1
    fi
    avbroot ota patch \
      --input "$ota" \
      --key-avb "$key_avb" \
      --key-ota "$key_ota" \
      --cert-ota "$cert_ota" \
      --magisk "$magisk_apk" \
      --magisk-preinit-device "$magisk_preinit_device" \
      ${PASSPHRASE_ARGS[@]:+"${PASSPHRASE_ARGS[@]}"}
    ;;
  prepatched)
    if [ -z "$prepatched_path" ]; then
      echo "For prepatched mode, --prepatched <file> is required."
      exit 1
    fi
    avbroot ota patch \
      --input "$ota" \
      --key-avb "$key_avb" \
      --key-ota "$key_ota" \
      --cert-ota "$cert_ota" \
      --prepatched "$prepatched_path" \
      ${PASSPHRASE_ARGS[@]:+"${PASSPHRASE_ARGS[@]}"}
    ;;
  rootless)
    avbroot ota patch \
      --input "$ota" \
      --key-avb "$key_avb" \
      --key-ota "$key_ota" \
      --cert-ota "$cert_ota" \
      --rootless \
      ${PASSPHRASE_ARGS[@]:+"${PASSPHRASE_ARGS[@]}"}
    ;;
  *)
    echo "Invalid mode: $mode"
    echo "Usage: $0 --ota <path_to_ota_zip> --mode <magisk|prepatched|rootless> ..."
    exit 1
    ;;
esac

echo "Patched OTA created successfully: $ota.patched"

echo "Verifying the patched OTA..."

# verify the patched OTA
avbroot ota verify -i "$ota.patched" 

echo "Patched OTA verified successfully."
