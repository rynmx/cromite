#!/usr/bin/env bash

set -eux

# Setup macOS build environment for Cromite
# Based on ungoogled-chromium's approach

_arch="${1:-arm64}"

echo "Setting up macOS build environment for ${_arch}"

# Cleanup and optimize environment
echo "Cleaning up Xcode installations..."
sudo mv /Applications/Xcode_16.4.app /Applications/tmp_Xcode_16.4.app || true
sudo rm -rf /Applications/Xcode* || true
sudo mv /Applications/tmp_Xcode_16.4.app /Applications/Xcode_16.4.app || true

echo "Selecting Xcode version..."
sudo xcode-select --switch /Applications/Xcode_16.4.app

echo "Cleaning up simulators..."
sudo xcrun simctl delete all || true

echo "Cleaning up Android SDK..."
sudo rm -rf "$ANDROID_HOME" || true

echo "Disabling Spotlight indexing..."
sudo mdutil -a -i off || true

# Show system resources
echo "System resources:"
df -h /
vm_stat

echo "Environment setup complete for ${_arch}"
