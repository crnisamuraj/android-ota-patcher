#!/usr/bin/env python3
"""
Google Pixel OTA Scraper

This script scrapes the latest OTA (Over-The-Air) update URLs from Google's 
official Android OTA page for Pixel devices using Selenium WebDriver.

Features:
- Multi-device support (any Pixel device codename)
- Configurable Chrome binary path (supports Flatpak Chrome)
- Optional download of OTA files
- Debug and silent modes
- Automatic ChromeDriver version matching

Usage:
    python3 scrape_ota_selenium.py --device cheetah --debug --no-download
    python3 scrape_ota_selenium.py --device cheetah --chrome-binary /path/to/chrome

Requirements:
    - Python 3.6+
    - selenium
    - webdriver-manager
    - requests
    - Chrome/Chromium browser

Author: Android OTA Patcher Project
"""

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
import time
import sys
import os
import requests
import argparse
import random
import subprocess
import re

# Google's official OTA page
GOOGLE_OTA_URL = "https://developers.google.com/android/ota"

def get_chrome_options(debug=False, chrome_binary_path=None):
    """
    Configure Chrome options for Selenium WebDriver with Flatpak compatibility.
    
    Args:
        debug (bool): If True, runs Chrome in non-headless mode for debugging
        chrome_binary_path (str): Path to Chrome binary (e.g., Flatpak Chrome)
    
    Returns:
        Options: Configured Chrome options object
    """
    options = Options()
    
    # Essential arguments for Flatpak Chrome and sandboxed environments
    options.add_argument('--no-sandbox')              # Disable sandbox for containers
    options.add_argument('--disable-dev-shm-usage')   # Overcome limited resource problems
    options.add_argument('--disable-gpu')             # Disable GPU acceleration
    options.add_argument('--no-first-run')            # Skip first run setup
    options.add_argument('--disable-web-security')    # Bypass CORS issues
    options.add_argument('--disable-features=VizDisplayCompositor')  # Fix display issues
    
    # Additional flags for container environments
    options.add_argument('--disable-extensions')      # Disable Chrome extensions
    options.add_argument('--disable-plugins')         # Disable all plugins
    options.add_argument('--no-zygote')              # Don't use zygote process
    options.add_argument('--single-process')          # Run in single process mode
    options.add_argument('--disable-background-timer-throttling')  # Prevent throttling
    options.add_argument('--disable-renderer-backgrounding')       # Prevent backgrounding
    options.add_argument('--disable-backgrounding-occluded-windows')  # Disable background optimization
    
    # Flags to disable X11 and DBus dependencies
    options.add_argument('--headless=new')            # Use new headless mode
    options.add_argument('--disable-software-rasterizer')  # Disable software rasterizer
    options.add_argument('--disable-background-networking')  # Disable background networking
    options.add_argument('--disable-default-apps')     # Disable default apps
    options.add_argument('--disable-component-update')  # Disable component updates
    options.add_argument('--no-default-browser-check')  # Skip default browser check
    options.add_argument('--use-gl=swiftshader')       # Use software GL implementation
    
    # Use a random port for remote debugging to avoid conflicts between sessions
    debug_port = random.randint(9222, 9999)
    options.add_argument(f'--remote-debugging-port={debug_port}')
    
    # Run headless unless debug mode is enabled
    if not debug:
        options.add_argument('--headless')
    
    # Set custom Chrome binary path if provided (useful for Flatpak installations)
    if chrome_binary_path:
        options.binary_location = chrome_binary_path
    
    return options


def setup_chrome_driver(chrome_binary_path=None, debug=False, silent=False):
    """
    Set up ChromeDriver with version matching for the installed Chrome.
    
    Args:
        chrome_binary_path (str): Path to Chrome binary
        debug (bool): Enable debug logging
        silent (bool): Suppress output
    
    Returns:
        Service: Configured ChromeDriver service
    """
    def log(msg):
        if debug and not silent:
            print(msg)
    
    try:
        # First try to use system ChromeDriver if available
        system_chromedriver = "/usr/bin/chromedriver"
        if os.path.exists(system_chromedriver):
            log(f"Using system ChromeDriver: {system_chromedriver}")
            return Service(system_chromedriver)
        
        # Fallback to webdriver-manager
        if chrome_binary_path:
            # For custom Chrome installations, detect version and match ChromeDriver
            result = subprocess.run([chrome_binary_path, '--version'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                version_output = result.stdout.strip()
                log(f"Chrome version: {version_output}")
                
                # Extract major version number to match with ChromeDriver
                version_match = re.search(r'Google Chrome (\d+)', version_output)
                if version_match:
                    chrome_major_version = version_match.group(1)
                    log(f"Chrome major version: {chrome_major_version}")
                    # Use ChromeDriverManager with specific version
                    return Service(ChromeDriverManager(
                        chrome_type="google-chrome", 
                        driver_version=chrome_major_version
                    ).install())
        
        # Fallback to default ChromeDriverManager
        return Service(ChromeDriverManager().install())
        
    except Exception as e:
        log(f"Could not setup ChromeDriver: {e}")
        # Final fallback - try to find chromedriver in PATH
        import shutil
        chromedriver_path = shutil.which('chromedriver')
        if chromedriver_path:
            log(f"Found ChromeDriver in PATH: {chromedriver_path}")
            return Service(chromedriver_path)
        else:
            raise Exception(f"ChromeDriver not found anywhere: {e}")

def get_latest_ota_zip(device_codename, debug=False, download=True, silent=False, chrome_binary_path=None):
    """
    Scrape the latest OTA ZIP URL for a specified Pixel device.
    
    Args:
        device_codename (str): Pixel device codename (e.g., 'cheetah', 'panther')
        debug (bool): Enable debug output and non-headless Chrome
        download (bool): If True, download the OTA file; if False, only print URL
        silent (bool): Silent mode - only print URLs, suppress other output
        chrome_binary_path (str): Path to Chrome binary for custom installations
    
    Returns:
        str: URL of the latest OTA ZIP file
    """
    def log(msg):
        """Helper function for conditional logging."""
        if debug and not silent:
            print(msg)

    if not silent:
        log(f"Launching Chrome and loading {GOOGLE_OTA_URL}")
    
    # Set up ChromeDriver with version matching
    service = setup_chrome_driver(chrome_binary_path, debug, silent)
    
    # Launch Chrome with configured options
    try:
        options = get_chrome_options(debug=debug, chrome_binary_path=chrome_binary_path)
        driver = webdriver.Chrome(service=service, options=options)
    except Exception as e:
        if not silent:
            log(f"Failed to launch Chrome: {e}")
        sys.exit(1)
    
    try:
        if not silent and debug:
            log(f"Chrome launched successfully. Current URL: {driver.current_url}")
        
        # Navigate to Google's OTA page
        driver.get(GOOGLE_OTA_URL)
        time.sleep(3)  # Wait for page to load completely
        
        current_url = driver.current_url
        if not silent and debug:
            log(f"Navigation complete. Current URL: {current_url}")
            log(f"Page title: {driver.title}")
        
        # Verify navigation was successful
        if current_url == "data:" or ("google" not in current_url.lower() and "developers" not in current_url.lower()):
            if not silent:
                log(f"Navigation may have failed. Current URL: {current_url}")
    
    except Exception as e:
        if not silent:
            log(f"Error during navigation: {e}")
        driver.quit()
        sys.exit(1)

    # Handle the acknowledgment button if present
    _handle_acknowledgment_button(driver, debug, silent)
    
    # Find and extract OTA information
    ota_url = _extract_latest_ota_url(driver, device_codename, debug, silent)
    
    # Close the browser
    driver.quit()

    # Download or just return the URL
    if download:
        _download_ota_file(ota_url, debug, silent)
    else:
        print(ota_url)

    return ota_url


def _handle_acknowledgment_button(driver, debug, silent):
    """Handle the acknowledgment button on Google's OTA page."""
    def log(msg):
        if debug and not silent:
            print(msg)
    
    if not silent:
        log("Checking for Acknowledge button...")
    
    try:
        acknowledge_btn = WebDriverWait(driver, 10).until(
            EC.element_to_be_clickable((By.XPATH, 
                '//button[contains(translate(., "ACKNOWLEDGE", "acknowledge"), "acknowledge")]'))
        )
        if not silent:
            log("Acknowledge button found, clicking...")
        acknowledge_btn.click()
        time.sleep(1)  # Brief pause after clicking
    except Exception:
        if not silent:
            log("No acknowledge button found, continuing...")


def _extract_latest_ota_url(driver, device_codename, debug, silent):
    """Extract the latest OTA URL for the specified device."""
    def log(msg):
        if debug and not silent:
            print(msg)
    
    if not silent:
        log(f"Locating the {device_codename} OTA table...")
    
    # Scroll to bottom to ensure all content is loaded
    driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
    time.sleep(2)
    
    # Find the device section header
    try:
        anchor = WebDriverWait(driver, 20).until(
            EC.presence_of_element_located((By.XPATH, f'//h2[@id="{device_codename}"]'))
        )
        if not silent:
            log(f'Found <h2 id="{device_codename}"> anchor for device.')
    except Exception:
        if debug and not silent:
            print(f'Could not find <h2 id="{device_codename}"> anchor after waiting.')
        driver.quit()
        sys.exit(1)

    # Find the OTA table following the device header
    table = _find_ota_table(anchor, device_codename, debug, silent, driver)
    
    # Extract table rows
    try:
        tbody = table.find_element(By.TAG_NAME, 'tbody')
        rows = tbody.find_elements(By.TAG_NAME, 'tr')
    except Exception:
        if debug and not silent:
            print("Could not find tbody or rows in the OTA table.")
        driver.quit()
        sys.exit(1)

    if not silent:
        log(f"Found {len(rows)} rows in the OTA table.")
    
    if not rows:
        if debug and not silent:
            print("No rows found in the OTA table.")
        driver.quit()
        sys.exit(1)

    # Get the latest (last) row and extract the download link
    latest_row = rows[-1]
    if not silent:
        log(f"Latest OTA row id: {latest_row.get_attribute('id')}")
    
    try:
        link_elem = latest_row.find_element(By.XPATH, './/a[contains(@href, ".zip")]')
        latest_link = link_elem.get_attribute('href')
    except Exception:
        if debug and not silent:
            print("No .zip link found in the latest OTA row.")
        driver.quit()
        sys.exit(1)

    if debug and not silent:
        print(f"Latest OTA zip for {device_codename}: {latest_link}")
    
    return latest_link


def _find_ota_table(anchor, device_codename, debug, silent, driver):
    """Find the OTA table following the device header."""
    try:
        # Try to find table in a div wrapper first
        return anchor.find_element(By.XPATH, 'following-sibling::div[1]/table')
    except Exception:
        try:
            # Fallback: find table directly following the header
            return anchor.find_element(By.XPATH, 'following-sibling::table[1]')
        except Exception:
            if debug and not silent:
                print(f"Could not find the OTA table after the <h2 id='{device_codename}'> anchor.")
            driver.quit()
            sys.exit(1)


def _download_ota_file(ota_url, debug, silent):
    """Download the OTA file from the given URL."""
    def log(msg):
        if debug and not silent:
            print(msg)
    
    if not silent:
        print(f"Downloading {ota_url} ...")
    
    local_filename = os.path.basename(ota_url)
    
    try:
        with requests.get(ota_url, stream=True) as r:
            r.raise_for_status()
            with open(local_filename, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
        if not silent:
            print(f"Downloaded to {local_filename}")
    except Exception as e:
        if not silent:
            print(f"Failed to download file: {e}")
        sys.exit(1)

def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description="Scrape and download latest Pixel OTA zip files from Google's official page.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --device cheetah --debug --no-download
    Get latest OTA URL for Pixel 7 Pro (cheetah) with debug output

  %(prog)s --device panther --chrome-binary /var/lib/flatpak/exports/bin/com.google.Chrome
    Download latest OTA for Pixel 7 (panther) using Flatpak Chrome

  %(prog)s --device cheetah --silent
    Download latest OTA for Pixel 7 Pro in silent mode

Common device codenames:
  cheetah    - Pixel 7 Pro
  panther    - Pixel 7
  bluejay    - Pixel 6a
  oriole     - Pixel 6
  raven      - Pixel 6 Pro
        """
    )
    
    parser.add_argument(
        '--device', 
        type=str, 
        required=True, 
        help='Device codename (e.g., cheetah, panther, bluejay, oriole, raven)'
    )
    parser.add_argument(
        '--debug', 
        action='store_true', 
        help='Enable debug output and run Chrome in non-headless mode'
    )
    parser.add_argument(
        '--no-download', 
        action='store_true', 
        help='Only print the latest OTA URL, do not download the file'
    )
    parser.add_argument(
        '--silent', 
        action='store_true', 
        help='Silent mode: only print download URLs, suppress all other output'
    )
    parser.add_argument(
        '--chrome-binary', 
        type=str, 
        help='Path to Chrome binary (e.g., for Flatpak: /var/lib/flatpak/exports/bin/com.google.Chrome)'
    )
    
    args = parser.parse_args()
    
    # Execute the main functionality
    get_latest_ota_zip(
        device_codename=args.device, 
        debug=args.debug, 
        download=not args.no_download, 
        silent=args.silent, 
        chrome_binary_path=args.chrome_binary
    )


if __name__ == "__main__":
    main()
