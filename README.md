# Patch Boot Script Documentation

This script is designed to extract and patch the boot image using a provided OTA zip and patched kernel.

## Usage
```bash
./patch-boot.sh <path_to_ota_zip> <path_to_patched_kernel_zip> [workdir]
```

### Arguments
- `<path_to_ota_zip>`: Path to the OTA zip file.
- `<path_to_patched_kernel_zip>`: Path to the zip file containing the patched kernel. (Anykernel3)
- `[workdir]`: Optional. Specify a directory to store all output files and use for relative paths. Defaults to the current directory.

### Steps Performed
1. Extract `payload.bin` from the OTA zip.
2. Extract images from `payload.bin`.
3. Extract `Image` from the patched kernel zip.
4. Replace the kernel in `boot.img` with the patched `Image`.
5. Repack the `boot.img` to create `new-boot.img`.

### Output
- `new-boot.img`: The patched boot image ready for use.

### Notes
- Ensure all required dependencies (`payload-dumper-go`, `magiskboot`) are installed and available in your PATH.
- Use the `WORKDIR` environment variable to override the default working directory for all output files.

### Example
```bash
./patch-boot.sh factory-ota.zip patched-kernel.zip path/to/workdir
```

# OTA Scraper for Pixel Devices

This project provides a robust, multi-device OTA (Over-The-Air) update scraper for Google Pixel devices. It automatically fetches the latest full OTA zip for each device from the official Google OTA page, downloads it, and tracks the last downloaded version for each device.

## Features
- Multi-device support (Pixel codenames)
- Device list can be set via command-line, environment variable, or fallback default
- Per-device state and download folders
- Designed for CI/CD automation (e.g., GitLab CI)
- Python Selenium-based scraping (handles JS, popups, etc.)

## Usage

### 1. Requirements
- Python 3.8+
- Google Chrome (or Chromium) installed
- ChromeDriver (auto-managed by script)

### 2. Running the Scraper

#### Basic (single device, default: cheetah)
```bash
bash run_ota_scraper.sh
```

#### Multi-device (via environment variable)
```bash
DEVICES="pixel7pro:cheetah pixel7:panther" bash run_ota_scraper.sh
```

#### Multi-device (via command-line argument)
```bash
bash run_ota_scraper.sh --devices="pixel7pro:cheetah pixel7:panther"
```

- Format: `foldername:codename` (folder for state/downloads, codename for scraping)
- Results and downloads are stored in `devices/<foldername>/`

### 3. Adding Devices
- Add more entries to the `DEVICES` variable or argument, e.g. `pixel6pro:raven`

### 4. CI/CD Integration
- The script is ready for scheduled runs in GitLab CI or similar systems.
- See `.gitlab-ci.yml` for an example job that commits the latest OTA info after each run.

### 5. Debugging
- Pass `--debug` to the Python script for verbose output.

## Files
- `run_ota_scraper.sh` — Main orchestrator script (multi-device, venv, etc.)
- `scrape_ota_selenium.py` — Python Selenium scraper for OTA zips
- `devices/<foldername>/` — Per-device state and downloads

## Example: Add Pixel 7 (panther)
Add to your device list:
```
DEVICES="pixel7pro:cheetah pixel7:panther"
```

## License
MIT