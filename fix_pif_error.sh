#!/bin/bash

echo "Fixing PIF transfer session error..."

# Close Xcode to ensure it's not locking any files
echo "Closing any running Xcode processes..."
killall Xcode 2>/dev/null

# Clear Xcode device logs and connection cache
echo "Clearing device connection caches..."
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/*
rm -rf ~/Library/Developer/CoreSimulator/Devices/*

# Clean project builds
echo "Cleaning project builds..."
cd ios/
rm -rf build/
rm -rf Pods/
rm -rf .symlinks/
rm -f Podfile.lock

# Repair bundle identifier issues
echo "Setting up bundle identifier..."
cat > Flutter/Debug.xcconfig << EOL
#include "Generated.xcconfig"
PRODUCT_BUNDLE_IDENTIFIER=com.mfchoudhury.fundracerapp
EOL

cat > Flutter/Release.xcconfig << EOL
#include "Generated.xcconfig"
PRODUCT_BUNDLE_IDENTIFIER=com.mfchoudhury.fundracerapp
EOL

# Install pods fresh
echo "Installing pods..."
pod install --repo-update

echo "✅ Fix complete!"
echo ""
echo "Now please follow these steps:"
echo "1. Unplug your iPhone"
echo "2. Wait 10 seconds"
echo "3. Plug your iPhone back in"
echo "4. Wait for your Mac to recognize the device (about 10-15 seconds)"
echo "5. Run: open Runner.xcworkspace"
echo "6. In Xcode, select your device, ensure signing is configured, and run the app" 