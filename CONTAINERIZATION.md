# Android OTA Patcher - Container Summary

## 📦 What Was Created

I've successfully containerized your Android OTA Patcher project with the following components:

### Core Container Files
- **`Containerfile`** - Main container definition (Fedora 40 based)
- **`entrypoint.sh`** - CLI interface and command router
- **`docker-compose.yml`** - Docker Compose configuration
- **`.containerignore`** - Files to exclude from container build

### Build and Setup Tools  
- **`build-container.sh`** - Container build script
- **`setup.sh`** - Interactive setup and initialization
- **`Makefile`** - Convenient command shortcuts
- **`run-examples.sh`** - Usage examples and testing

### Documentation
- **`CONTAINER.md`** - Comprehensive container usage guide
- **`README.md`** - Updated with container instructions
- **`.env.sample`** - Environment configuration template

### CI/CD Integration
- **`.github/workflows/build.yml`** - Automated container builds
- **`.github/workflows/test.yml`** - Script testing workflow

## 🚀 Quick Start

1. **Initial Setup:**
   ```bash
   ./setup.sh
   ```

2. **Add Your Keys:**
   ```bash
   # Copy to keys/ directory:
   # - avb.key (AVB signing key)
   # - ota.key (OTA signing key)  
   # - ota.crt (OTA certificate)
   # - Magisk-v29.0.apk (Magisk APK)
   ```

3. **Use the Container:**
   ```bash
   make scrape device=cheetah    # Get OTA URL
   make download device=cheetah  # Download OTA
   make ci                       # Full pipeline
   ```

## 🛠 Container Features

### Included Software
- **Fedora 40** base system
- **Chromium** for web scraping
- **Python 3** with selenium, webdriver-manager, pyyaml
- **avbroot** for OTA patching
- **payload-dumper-go** for boot image extraction
- **magiskboot** for boot image manipulation
- **android-tools** (adb, fastboot)

### Supported Workflows
- **Scrape** - Get latest OTA URLs from Google
- **Download** - Download OTA files
- **Patch** - Patch with Magisk, prepatched boot, or rootless
- **CI Pipeline** - Automated check/download/patch workflow
- **Boot Patching** - Extract and patch boot images
- **Sideload** - Install patched OTAs to devices

### Volume Mounts
- **`/data`** - Working directory for downloads/output
- **`/workspace/keys`** - Signing keys and certificates
- **`/dev/bus/usb`** - USB device access (for sideload)

## 📱 Supported Devices

The container works with any Pixel device supported by your `devices.yaml`:
- **Pixel 7 Pro** (cheetah) - Default
- **Pixel 8** (shiba) 
- Any other Pixel device (add to devices.yaml)

## 🔧 Usage Examples

### CLI Commands
```bash
# Container help
podman run --rm android-ota-patcher

# Scrape OTA URL  
podman run --rm android-ota-patcher scrape --device cheetah

# Download with volume mount
podman run --rm -v ./data:/data android-ota-patcher download --device cheetah

# Full CI with keys
podman run --rm -v ./data:/data -v ./keys:/workspace/keys android-ota-patcher ci
```

### Make Commands (Recommended)
```bash
make help                     # Show all options
make scrape device=cheetah    # Scrape OTA
make download device=cheetah  # Download OTA  
make ci                       # Run CI pipeline
make shell                    # Interactive shell
```

### Docker Compose
```bash
docker-compose up ota-ci      # CI pipeline
docker-compose run ota-shell  # Interactive shell
```

## 🔒 Security Features

- **Read-only key mounts** - Keys mounted as read-only
- **Non-root execution** - Container runs as non-privileged user
- **Minimal attack surface** - Only essential packages installed
- **Automated security scanning** - Trivy scans in CI/CD

## 📖 Next Steps

1. **Setup:** Run `./setup.sh` to get started
2. **Keys:** Add your signing keys to `./keys/` directory  
3. **Test:** Use `make scrape device=cheetah` to test functionality
4. **Automate:** Set up CI/CD with `make ci` or docker-compose
5. **Customize:** Edit `devices.yaml` to add more Pixel devices

The containerized solution provides a clean, portable, and automated way to manage Pixel OTA updates with proper dependency isolation and easy deployment! 🎉
