
# patch-boot.sh
#
# Description:
#   This script extracts the boot image (boot.img) from a Google Pixel OTA zip, replaces its kernel with a patched kernel (from a provided zip),
#   and repacks the boot image using Magisk tools. The result is a new-boot.img ready for flashing or further use.
#
# Usage:
#   ./patch-boot.sh <path_to_ota_zip> <path_to_patched_kernel_zip> [workdir]
#
#   <path_to_ota_zip>            Path to the original OTA zip file (e.g., cheetah-ota-*.zip)
#   <path_to_patched_kernel_zip> Path to the zip file containing the patched kernel (must contain an 'Image' file)
#   [workdir]                    Optional. Working directory for relative paths and output (defaults to current directory)
#
# Requirements:
#   - payload-dumper-go (must be in PATH)
#   - magiskboot (must be in PATH)
#   - unzip
#
# Output:
#   - new-boot.img in the specified or current working directory
#
# Example:
#   ./patch-boot.sh cheetah-ota-bp2a.250605.031.a2-0662933e.zip NEXT-android14-6.1.124-2025-02-AnyKernel3.zip ./605
#
#!/bin/bash

workdir=${WORKDIR:-$3}
if [ -z "$workdir" ]; then
  workdir="$(pwd)"
fi

echo "Using work directory: $workdir"
# Change to the specified work directory
cd "$workdir"

# Ensure workdir is an absolute path
workdir="$(pwd)"
echo "full path: $workdir"

ota_zip=$1
if [ -z "$ota_zip" ]; then
  echo "Usage: $0 <path_to_ota_zip> <path_to_patched_kernel_zip> [workdir used for relative paths and results]"
  exit 1
fi

# Check if the provided file exists
if [ ! -f "$ota_zip" ]; then
  echo "Error: File $ota_zip does not exist."
  exit 1
fi

patched_kernel_zip=$2
if [ -z "$patched_kernel_zip" ]; then
  echo "Usage: $0 <path_to_ota_zip> <path_to_patched_kernel_zip> [workdir used for relative paths and results]"
  exit 1
fi

# Check if the patched kernel zip exists
if [ ! -f "$patched_kernel_zip" ]; then
  echo "Error: File $patched_kernel_zip does not exist."
  exit 1
fi

# Create a shared temporary directory for all extraction operations
temp_dir=$(mktemp -d)

# Extract payload.bin from the OTA zip
unzip -j "$ota_zip" payload.bin -d "$temp_dir"

# Check if payload.bin was successfully extracted
if [ ! -f "$temp_dir/payload.bin" ]; then
  echo "Error: payload.bin not found in $ota_zip."
  rm -rf "$temp_dir"
  exit 1
fi

# Ensure payload-dumper-go is available
if ! command -v payload-dumper-go &> /dev/null; then
  echo "Error: payload-dumper-go command not found. Please install it or ensure it's in your PATH."
  rm -rf "$temp_dir"
  exit 1
fi

# Extract images from payload.bin
payload-dumper-go -o "$temp_dir" -p "boot" "$temp_dir/payload.bin"

# Get boot.img from extracted images
boot_img="$temp_dir/boot.img"
if [ ! -f "$boot_img" ]; then
  echo "Error: boot.img not found in extracted images."
  rm -rf "$temp_dir"
  exit 1
fi

# check kernel version from extracted ota boot img.
strings $boot_img | grep android

# Extract Image from patched kernel zip
unzip -j "$patched_kernel_zip" Image -d "$temp_dir"
if [ ! -f "$temp_dir/Image" ]; then
  echo "Error: Image not found in patched kernel zip."
  rm -rf "$temp_dir"
  exit 1
fi
patched_kernel="$temp_dir/Image"

# Ensure magiskboot is available
if ! command -v magiskboot &> /dev/null; then
  echo "Error: magiskboot command not found. Please install Magisk or ensure it's in your PATH."
  rm -rf "$temp_dir"
  exit 1
fi

cd "$temp_dir"

# Unpack boot.img
magiskboot unpack "$boot_img"

# Replace kernel
mv -f "$patched_kernel" kernel

# Repack boot.img
magiskboot repack "$boot_img"

cd "$workdir"

# Move new-boot.img to current directory
mv "$temp_dir/new-boot.img" "$workdir/new-boot.img"

# Clean up temporary directory
rm -rf "$temp_dir"

echo "new-boot.img has been prepared and is ready for use as a prepatched image."
