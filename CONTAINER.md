# Container Usage Guide

This guide covers how to use the Android OTA Patcher container for automated Pixel OTA downloading and patching.

## Quick Start

1. **Setup and Build:**
   ```bash
   ./setup.sh
   ```

2. **Basic Usage:**
   ```bash
   make help                     # Show all commands
   make scrape device=cheetah    # Get OTA URL for Pixel 7 Pro
   make download device=cheetah  # Download OTA
   make ci                       # Full CI pipeline
   ```

## Container Commands Reference

### Scraping Commands
```bash
# Get latest OTA URL (no download)
podman run --rm android-ota-patcher scrape --device cheetah

# With debug output
podman run --rm android-ota-patcher scrape --device cheetah --debug

# For different device  
podman run --rm android-ota-patcher scrape --device shiba  # Pixel 8
```

### Download Commands
```bash
# Download to default location (/data)
podman run --rm -v ./data:/data android-ota-patcher download --device cheetah

# Download to specific directory
podman run --rm -v ./data:/data android-ota-patcher download --device cheetah --output-dir /data/pixel7pro
```

### Patching Commands
```bash
# Rootless patch (no root access)
podman run --rm \
  -v ./data:/data \
  -v ./keys:/workspace/keys \
  android-ota-patcher patch --ota /data/ota.zip --mode rootless

# Magisk patch
podman run --rm \
  -v ./data:/data \
  -v ./keys:/workspace/keys \
  android-ota-patcher patch \
  --ota /data/ota.zip \
  --mode magisk \
  --magisk-preinit-device /dev/block/by-name/preinit

# Pre-patched boot image
podman run --rm \
  -v ./data:/data \
  -v ./keys:/workspace/keys \
  android-ota-patcher patch \
  --ota /data/ota.zip \
  --mode prepatched \
  --prepatched /data/new-boot.img
```

### CI Pipeline
```bash
# Default device (cheetah)
podman run --rm \
  -v ./data:/data \
  -v ./keys:/workspace/keys \
  android-ota-patcher ci

# Multiple devices
podman run --rm \
  -v ./data:/data \
  -v ./keys:/workspace/keys \
  android-ota-patcher ci --devices "cheetah:cheetah pixel8:shiba"
```

### Boot Image Patching
```bash
# Extract and patch boot with custom kernel
podman run --rm -v ./data:/data android-ota-patcher boot-patch \
  /data/ota.zip \
  /data/custom-kernel.zip \
  /data/workdir
```

### Device Operations
```bash
# List configured devices
podman run --rm android-ota-patcher devices

# Get device codenames only
podman run --rm android-ota-patcher devices --field codename

# Interactive shell
podman run --rm -it \
  -v ./data:/data \
  -v ./keys:/workspace/keys \
  android-ota-patcher shell
```

### Sideload to Device
```bash
# Using Make with direct container (requires file parameter)
make sideload file=/data/ota.zip.patched

# Using Docker Compose (uses default file path)
make sideload-compose

# Or directly with Docker Compose
docker-compose run --rm ota-sideload

# Manual container run (requires USB access)
podman run --rm \
  -v ./data:/data \
  --privileged \
  -v /dev/bus/usb:/dev/bus/usb \
  android-ota-patcher sideload /data/ota.zip.patched
```

## Volume Mounts

### Required Volumes

- **`/data`** - Working directory for downloads and output
- **`/workspace/keys`** - Signing keys and certificates (read-only)

### Optional Volumes

- **`/dev/bus/usb`** - USB device access for sideloading
- **`/workspace/config`** - Custom configuration files

## Environment Variables

```bash
# Enable debug output
-e DEBUG=1

# Set default devices for CI
-e DEVICES="cheetah:cheetah pixel8:shiba"  

# Custom data directory inside container
-e DATA_DIR=/data

# Custom Chrome binary path
-e CHROME_BINARY=/usr/bin/chromium-browser
```

## Docker Compose Usage

### Basic Services
```bash
# Show help
docker-compose run ota-patcher

# Run CI pipeline  
docker-compose up ota-ci

# Interactive shell
docker-compose run ota-shell
```

### Custom Commands
```bash
# Override command in compose
docker-compose run ota-patcher scrape --device cheetah

# One-off download
docker-compose run ota-patcher download --device cheetah

# Sideload with USB access
docker-compose run ota-sideload
```

## Makefile Usage

The included Makefile provides convenient shortcuts:

```bash
make build                    # Build container
make setup                    # Create directories  
make help                     # Show all commands
make scrape device=cheetah    # Scrape OTA URL
make download device=cheetah  # Download OTA
make ci                       # Run CI pipeline
make shell                    # Interactive shell
make clean                    # Clean up container and cache
```

### Device-Specific Shortcuts
```bash
make pixel7pro               # Scrape for Pixel 7 Pro
make pixel8                  # Scrape for Pixel 8
```

### Example Workflows
```bash
make example-scrape          # Example scrape command
make example-download        # Example download command  
make example-patch-rootless  # Example rootless patch
make example-ci              # Example CI pipeline
```

## Required Files

Place these files in your `keys/` directory:

- **`avb.key`** - AVB signing private key (4096-bit RSA)
- **`ota.key`** - OTA signing private key (4096-bit RSA)
- **`ota.crt`** - OTA certificate (X.509, matches ota.key)
- **`Magisk-v29.0.apk`** - Magisk APK for root patching

### Generate Keys
```bash
# Generate AVB key
openssl genrsa -out keys/avb.key 4096

# Generate OTA key and certificate
openssl genrsa -out keys/ota.key 4096
openssl req -new -x509 -key keys/ota.key -out keys/ota.crt -days 365
```

## Troubleshooting

### Chrome/Browser Issues
- The container uses Chromium in headless mode
- For systems with different Chrome installations, see `CHROME_CONFIG.md`
- Debug with `--debug` flag to see browser output

### Permission Issues
- Ensure `data/` and `keys/` directories are readable/writable
- For sideload operations, use `--privileged` flag
- Check SELinux/AppArmor policies if volumes don't mount

### Network Issues
- Container needs internet access for OTA scraping and downloads
- Some corporate firewalls may block the Google OTA site
- Use `--debug` to see detailed network operations

### Storage Issues
- OTA files can be 2-4GB each, ensure adequate disk space
- Use `make clean` to remove old containers and free space
- Check `docker system df` or `podman system df` for usage

### Key and Certificate Issues
- Ensure keys are in PEM format
- Verify certificate matches the private key:
  ```bash
  openssl rsa -noout -modulus -in keys/ota.key | openssl md5
  openssl x509 -noout -modulus -in keys/ota.crt | openssl md5
  # These should match
  ```
