#!/usr/bin/env bash

set -eux

# Prepare build artifacts for upload
# Based on ungoogled-chromium's artifact handling

_arch="${1:-arm64}"
_build_dir="out/mac_${_arch}"

echo "Preparing artifacts for ${_arch}"

# Create upload directories
mkdir -p upload_build_state
mkdir -p upload_logs
mkdir -p upload_release

cd $WORKSPACE/chromium/src

# Archive build state for potential resumption
if [ -d "${_build_dir}" ]; then
    echo "Archiving build state..."
    
    # Save essential build state files
    tar -czf upload_build_state/build_state_${_arch}.tar.gz \
        "${_build_dir}/build_status.txt" \
        "${_build_dir}/gn_list" \
        "${_build_dir}/args.gn" \
        "${_build_dir}/build.ninja" \
        "${_build_dir}/obj" \
        2>/dev/null || true
    
    echo "Build state archived"
fi

# Collect logs
echo "Collecting logs..."
if [ -f "build_start_time.txt" ]; then
    cp build_start_time.txt upload_logs/
fi

# Copy any log files
find . -name "*.log" -maxdepth 1 -exec cp {} upload_logs/ \; 2>/dev/null || true

# If build is finished, prepare release artifacts
_build_status="unknown"
if [ -f "${_build_dir}/build_status.txt" ]; then
    _build_status=$(cat "${_build_dir}/build_status.txt")
fi

if [ "${_build_status}" = "finished" ]; then
    echo "Preparing release artifacts..."
    
    # Find and copy DMG files
    if ls "${_build_dir}"/cromite-*-macos-"${_arch}".dmg 1> /dev/null 2>&1; then
        cp "${_build_dir}"/cromite-*-macos-"${_arch}".dmg upload_release/
        cp "${_build_dir}"/cromite-*-macos-"${_arch}".dmg.sha256 upload_release/ 2>/dev/null || true
        
        _dmg_name=$(ls "${_build_dir}"/cromite-*-macos-"${_arch}".dmg | head -1 | xargs basename)
        echo "dmg_name=${_dmg_name}" >> $GITHUB_OUTPUT
        echo "Release artifacts prepared: ${_dmg_name}"
    fi
    
    # Copy Chromium.app for debugging if needed
    if [ -d "${_build_dir}/Chromium.app" ]; then
        echo "Chromium.app size: $(du -sh ${_build_dir}/Chromium.app | cut -f1)"
    fi
fi

echo "status=${_build_status}" >> $GITHUB_OUTPUT
echo "Artifact preparation complete"
