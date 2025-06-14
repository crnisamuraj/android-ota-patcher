#!/bin/bash
ota=$1
mode=$2
if [ -z "$ota" ] || [ -z "$mode" ]; then
  echo "Usage: $0 <path_to_ota_zip> <mode: magisk | prepatched | rootless>"
  exit 1
fi

key_avb=${KEY_AVB:-avb.key}
key_ota=${KEY_OTA:-ota.key}
cert_ota=${CERT_OTA:-ota.crt}

case "$mode" in
  magisk)
    magisk_apk=$3
    magisk_preinit_device=$4
    if [ -z "$magisk_apk" ] || [ -z "$magisk_preinit_device" ]; then
      echo "Usage: $0 <path_to_ota_zip> magisk <path_to_magisk_apk> <magisk_preinit_device>"
      exit 1
    fi
    avbroot ota patch \
    --input "$ota" \
    --key-avb "$key_avb" \
    --key-ota "$key_ota" \
    --cert-ota "$cert_ota" \
    --magisk "$magisk_apk" \
    --magisk-preinit-device "$magisk_preinit_device"
    ;;
  prepatched)
    prepatched_path=$3
    if [ -z "$prepatched_path" ]; then
      echo "Usage: $0 <path_to_ota_zip> prepatched <path_to_prepatched_file>"
      exit 1
    fi
    avbroot ota patch \
    --input "$ota" \
    --key-avb "$key_avb" \
    --key-ota "$key_ota" \
    --cert-ota "$cert_ota" \
    --prepatched "$prepatched_path"
    ;;
  rootless)
    avbroot ota patch \
    --input "$ota" \
    --key-avb "$key_avb" \
    --key-ota "$key_ota" \
    --cert-ota "$cert_ota" \
    --rootless
    ;;
  *)
    echo "Invalid mode: $mode"
    echo "Usage: $0 <path_to_ota_zip> <mode: magisk | prepatched | rootless>"
    exit 1
    ;;
esac

# verify the patched OTA
avbroot ota verify -i "$ota.patched"

# Wait for device to be connected
while true; do
  device_state=$(adb get-state 2>/dev/null)
  if [ "$device_state" == "device" ]; then
    echo "Device connected. Proceeding with sideload."
    break
  fi
  echo "Waiting for device to connect..."
  sleep 5
done

sleep 1
echo "Sideloading the patched OTA..."
adb sideload "$ota.patched"
