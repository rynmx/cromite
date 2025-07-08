#!/usr/bin/env bash

set -eux

# macOS packaging script for Cromite
# Based on ungoogled-chromium's packaging approach

_root_dir="$(dirname "$(readlink -f "$0")")"
_src_dir="${_root_dir}/../chromium/src"
_arch="${1:-arm64}"
_build_dir="out/mac_${_arch}"

# Ensure we're in the right directory
cd "${_src_dir}"

# Verify the build exists
if [ ! -f "${_build_dir}/Chromium.app/Contents/MacOS/Chromium" ]; then
    echo "Error: Chromium.app not found in ${_build_dir}"
    exit 1
fi

echo "Packaging Cromite for macOS (${_arch})..."

# Fix network permissions issue
echo "Fixing network permissions..."
xattr -cs "${_build_dir}/Chromium.app"

# Create a copy with the Cromite branding
echo "Creating Cromite.app..."
rm -rf "${_build_dir}/Cromite.app" || true
cp -r "${_build_dir}/Chromium.app" "${_build_dir}/Cromite.app"

# Update app bundle identifier and name for Cromite
if [ -f "${_build_dir}/Cromite.app/Contents/Info.plist" ]; then
    echo "Updating app bundle info..."
    # Update bundle identifier
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier org.cromite.cromite" "${_build_dir}/Cromite.app/Contents/Info.plist" || true
    # Update app name
    /usr/libexec/PlistBuddy -c "Set :CFBundleName Cromite" "${_build_dir}/Cromite.app/Contents/Info.plist" || true
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Cromite" "${_build_dir}/Cromite.app/Contents/Info.plist" || true
fi

# Ad-hoc code signing
echo "Performing ad-hoc code signing..."
codesign --force --deep --sign - "${_build_dir}/Cromite.app"

# Verify the signature
echo "Verifying code signature..."
codesign --verify --deep --verbose=2 "${_build_dir}/Cromite.app"

# Get version info for packaging
_cromite_version=$(cat "${_root_dir}/RELEASE" 2>/dev/null || echo "unknown")

# Create DMG package
echo "Creating DMG package..."
_dmg_name="cromite-${_cromite_version}-macos-${_arch}.dmg"
rm -f "${_build_dir}/${_dmg_name}" || true

# Create temporary directory for DMG contents
_temp_dmg_dir="${_build_dir}/dmg_temp"
rm -rf "${_temp_dmg_dir}" || true
mkdir -p "${_temp_dmg_dir}"

# Copy app to temp directory
cp -r "${_build_dir}/Cromite.app" "${_temp_dmg_dir}/"

# Create Applications symlink
ln -s /Applications "${_temp_dmg_dir}/Applications"

# Create DMG
hdiutil create -volname "Cromite" -srcfolder "${_temp_dmg_dir}" -ov -format UDZO "${_build_dir}/${_dmg_name}"

# Cleanup temp directory
rm -rf "${_temp_dmg_dir}"

echo "✓ Successfully created ${_dmg_name}"
echo "✓ Package location: ${_build_dir}/${_dmg_name}"

# Generate checksums
echo "Generating checksums..."
cd "${_build_dir}"
shasum -a 256 "${_dmg_name}" > "${_dmg_name}.sha256"
echo "✓ SHA256 checksum: $(cat ${_dmg_name}.sha256)"

echo "✓ macOS packaging complete!"
