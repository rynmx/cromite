#!/usr/bin/env bash

set -eux

# Build Cromite for macOS
# Based on ungoogled-chromium's resumable build approach

_arch="${1:-arm64}"
_build_dir="out/mac_${_arch}"
_timeout_seconds=5400  # 90 minutes

echo "Building Cromite for macOS ${_arch}"

# Set up environment
PATH=$WORKSPACE/chromium/src/third_party/llvm-build/Release+Asserts/bin:$WORKSPACE/depot_tools/:/usr/local/go/bin:$WORKSPACE/mtool/bin:$PATH
cd $WORKSPACE/chromium/src

# Record start time
echo $(date +%s) > build_start_time.txt

# Check if this is a resumed build
if [ -f "${_build_dir}/build_status.txt" ]; then
    echo "Resuming build from previous state"
    _build_status=$(cat "${_build_dir}/build_status.txt")
    echo "Previous build status: ${_build_status}"
else
    echo "Starting fresh build"
    
    # Generate build files
    echo "Generating build files..."
    gn gen --args="target_os = \"mac\" $(cat /home/lg/working_dir/cromite/build/cromite.gn_args) target_cpu = \"${_arch}\" " "${_build_dir}"
    
    # Verify build configuration
    echo "Build configuration:"
    gn args "${_build_dir}/" --list --short
    gn args "${_build_dir}/" --list >"${_build_dir}/gn_list"
    
    echo "running" > "${_build_dir}/build_status.txt"
fi

# Build with timeout
echo "Starting ninja build..."
if timeout ${_timeout_seconds}s ninja -C "${_build_dir}" -j 4 chrome; then
    echo "Build completed successfully"
    echo "finished" > "${_build_dir}/build_status.txt"
    echo "status=finished" >> $GITHUB_OUTPUT
else
    _exit_code=$?
    if [ $_exit_code -eq 124 ]; then
        echo "Build timed out - will be resumed in next job"
        echo "running" > "${_build_dir}/build_status.txt"
        echo "status=running" >> $GITHUB_OUTPUT
    else
        echo "Build failed with exit code $_exit_code"
        echo "failed" > "${_build_dir}/build_status.txt"
        echo "status=failed" >> $GITHUB_OUTPUT
        exit $_exit_code
    fi
fi

# Copy release info
cp ../../cromite/build/RELEASE "${_build_dir}/"

# Check if Chromium.app was built
if [ -f "${_build_dir}/Chromium.app/Contents/MacOS/Chromium" ]; then
    echo "✓ Chromium.app built successfully"
    ls -la "${_build_dir}/Chromium.app/Contents/MacOS/"
    
    # Package if build is finished
    if [ "$(cat ${_build_dir}/build_status.txt)" = "finished" ]; then
        echo "Creating macOS package..."
        ../../cromite/build/package_macos.sh "${_arch}"
        
        # Set output for artifact upload
        _dmg_name=$(ls "${_build_dir}"/cromite-*-macos-"${_arch}".dmg | head -1 | xargs basename)
        echo "dmg_name=${_dmg_name}" >> $GITHUB_OUTPUT
    fi
else
    echo "Chromium.app not found - build incomplete"
fi

echo "Build script completed"
