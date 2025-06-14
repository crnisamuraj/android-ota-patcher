#!/bin/bash

# Wait for device to be connected
while true; do
  device_state=$(adb get-state)
  if [ "$device_state" == "device" ]; then
    echo "Device connected. Proceeding with sideload."
    break
  fi
  echo "Waiting for device to connect..."
  sleep 5
done

sleep 1
echo "Sideloading the patched OTA..."
adb sideload "$@"
