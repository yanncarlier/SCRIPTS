#!/bin/bash
# setup_lean_flutter.sh - Optimized for Flutter 3.41+ on Ubuntu 24.04
# No Android Studio required. High-performance SRE/Platform setup.

set -e

SDK_DIR="$HOME/android-sdk"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

echo "### 1. Ensuring Clean Directory Structure..."
mkdir -p "$SDK_DIR/cmdline-tools"

# Only download if 'latest' doesn't exist to save bandwidth
if [ ! -d "$SDK_DIR/cmdline-tools/latest" ]; then
    echo "### 2. Downloading Android Command Line Tools..."
    cd "$SDK_DIR/temp_download" 2>/dev/null || mkdir -p "$SDK_DIR/temp_download" && cd "$SDK_DIR/temp_download"
    curl -o tools.zip $CMDLINE_TOOLS_URL
    unzip -q tools.zip
    mv cmdline-tools "$SDK_DIR/cmdline-tools/latest"
    cd "$SDK_DIR"
    rm -rf "$SDK_DIR/temp_download"
else
    echo "### 2. Command Line Tools already present. Skipping download."
fi

echo "### 3. Installing Required Platforms and Build Tools (API 36 & 28.0.3)..."
# Explicitly installing exactly what Flutter 3.41 requested
"$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK_DIR" \
    "platform-tools" \
    "platforms;android-36" \
    "build-tools;36.0.0" \
    "build-tools;28.0.3"

echo "### 4. Configuring Shell Environment..."
# Check if ANDROID_HOME is already in .bashrc to avoid duplicates
if ! grep -q "ANDROID_HOME" "$HOME/.bashrc"; then
    {
        echo ""
        echo "# Android SDK paths for Lean Flutter"
        echo "export ANDROID_HOME=$SDK_DIR"
        echo "export PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools"
    } >> "$HOME/.bashrc"
    echo "Environment variables added to .bashrc."
fi

echo "### 5. Cleaning Flutter Config & Accepting Licenses..."
# Clear the old Android Studio path and point to the new SDK
flutter config --android-studio-dir=""
flutter config --android-sdk "$SDK_DIR"

echo "Please accept the licenses below:"
yes | flutter doctor --android-licenses

echo "--------------------------------------------------------"
echo "Setup Complete!"
echo "Run: source ~/.bashrc"
echo "Then run: flutter doctor"
echo "--------------------------------------------------------"