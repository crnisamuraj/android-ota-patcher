# This script is now multi-device. Rename to scrape_ota_selenium.py for clarity.
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from webdriver_manager.chrome import ChromeDriverManager
import time
import sys
import os
import requests
import argparse

URL = "https://developers.google.com/android/ota"

options = Options()
# Run headless unless debug is set
if not (hasattr(sys, 'argv') and ('--debug' in sys.argv)):
    options.add_argument('--headless')
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')

def get_latest_ota_zip(device_codename, debug=False, download=True, silent=False):
    def log(msg):
        if debug and not silent:
            print(msg)

    if not silent:
        log(f"Launching Chrome and loading {URL}")
    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)
    driver.get(URL)
    time.sleep(5)

    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    if not silent:
        log("Checking for Acknowledge button...")
    try:
        acknowledge_btn = WebDriverWait(driver, 10).until(
            EC.element_to_be_clickable((By.XPATH, '//button[contains(translate(., "ACKNOWLEDGE", "acknowledge"), "acknowledge")]'))
        )
        if not silent:
            log("Acknowledge button found, clicking...")
        acknowledge_btn.click()
        time.sleep(1)
    except Exception:
        if not silent:
            log("No acknowledge button found, continuing...")

    if not silent:
        log(f"Locating the {device_codename} OTA table...")
    driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
    time.sleep(2)
    anchor = None
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

    table = None
    try:
        table = anchor.find_element(By.XPATH, 'following-sibling::div[1]/table')
    except Exception:
        try:
            table = anchor.find_element(By.XPATH, 'following-sibling::table[1]')
        except Exception:
            if debug and not silent:
                print(f"Could not find the OTA table after the <h2 id='{device_codename}'> anchor.")
            driver.quit()
            sys.exit(1)

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
    driver.quit()

    if download:
        if not silent:
            print(f"Downloading {latest_link} ...")
        local_filename = os.path.basename(latest_link)
        try:
            with requests.get(latest_link, stream=True) as r:
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
    else:
        print(latest_link)

    return latest_link

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Scrape and download latest Pixel OTA zip.")
    parser.add_argument('--device', type=str, required=True, help='Device codename (e.g. cheetah, panther, etc.)')
    parser.add_argument('--debug', action='store_true', help='Enable debug output')
    parser.add_argument('--no-download', action='store_true', help='Only print the latest OTA URL, do not download')
    parser.add_argument('--silent', action='store_true', help='Silent mode: only print download URL(s)')
    args = parser.parse_args()

    get_latest_ota_zip(device_codename=args.device, debug=args.debug, download=not args.no_download, silent=args.silent)
