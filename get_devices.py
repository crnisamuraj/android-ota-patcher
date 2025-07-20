#!/usr/bin/env python3
"""
get_devices.py

Reads devices.yaml and prints device info in a shell-friendly format for use in CI scripts.

Usage:
  python3 get_devices.py [--field FIELD]

  --field FIELD   (optional) Only print the specified field for each device (e.g., codename)

Example:
  python3 get_devices.py
  python3 get_devices.py --field codename
"""
import sys
import yaml
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--field', type=str, help='Only print this field for each device')
args = parser.parse_args()

with open('devices.yaml') as f:
    data = yaml.safe_load(f)

devices = data.get('devices', [])

if args.field:
    for d in devices:
        print(d.get(args.field, ''))
else:
    for d in devices:
        print(d)
