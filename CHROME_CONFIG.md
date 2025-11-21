# Chrome Configuration for OTA Scraper

This document explains how to configure Chrome installations for the OTA scraper script, particularly for immutable distributions using Flatpak.

## Quick Setup (Recommended)

1. Run the automatic configuration script:
   ```bash
   ./setup_chrome_config.sh
   ```

   This will detect your Chrome installation and automatically configure `chrome_paths.conf`.

## Manual Configuration

### Option 1: Using Configuration File

1. Edit `chrome_paths.conf` and uncomment the appropriate line for your Chrome installation:
   ```bash
   # For Flatpak Google Chrome (most common on immutable distros)
   CHROME_BINARY=/var/lib/flatpak/exports/bin/com.google.Chrome
   
   # For Flatpak Chromium
   CHROME_BINARY=/var/lib/flatpak/exports/bin/org.chromium.Chromium
   
   # For native installations
   CHROME_BINARY=/usr/bin/google-chrome
   ```

2. Run the scraper normally - it will automatically use the configured Chrome binary:
   ```bash
   ./run_ota_scraper.sh --device cheetah --no-download
   ```

### Option 2: Command Line Parameter

You can also specify the Chrome binary path directly when running the scraper:

```bash
./run_ota_scraper.sh --device cheetah --no-download --chrome-binary /var/lib/flatpak/exports/bin/com.google.Chrome
```

## Common Chrome Paths

### Flatpak Installations
- Google Chrome: `/var/lib/flatpak/exports/bin/com.google.Chrome`
- Chromium: `/var/lib/flatpak/exports/bin/org.chromium.Chromium`

### Native Package Installations
- Google Chrome: `/usr/bin/google-chrome` or `/usr/bin/google-chrome-stable`
- Chromium: `/usr/bin/chromium-browser` or `/usr/bin/chromium`

### Snap Installations
- Google Chrome: `/snap/bin/google-chrome`
- Chromium: `/snap/bin/chromium`

## Priority Order

The Chrome binary is selected in this order:
1. Command line `--chrome-binary` parameter (highest priority)
2. `CHROME_BINARY` variable from `chrome_paths.conf`
3. System default (ChromeDriverManager will try to find Chrome automatically)

## Troubleshooting

If you get Chrome-related errors:

1. Verify your Chrome installation:
   ```bash
   # For Flatpak
   flatpak list | grep -i chrome
   
   # For native
   which google-chrome
   ```

2. Test the Chrome binary path:
   ```bash
   # Replace with your actual path
   /var/lib/flatpak/exports/bin/com.google.Chrome --version
   ```

3. Run the scraper with debug output:
   ```bash
   ./run_ota_scraper.sh --device cheetah --no-download --debug --chrome-binary /path/to/chrome
   ```
