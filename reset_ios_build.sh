#!/bin/bash

echo "Performing deep clean of iOS build environment..."

# Kill any running Xcode processes
echo "Closing any running Xcode processes..."
killall Xcode 2>/dev/null
killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null

# Clear Xcode derived data and caches
echo "Clearing Xcode derived data and caches..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Caches/com.apple.dt.Xcode/*
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/*

# Clean up project-specific files
echo "Cleaning project files..."
cd ios/
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock
rm -rf build
rm -rf .xcode.env.local
cd ..

# Reset iOS device connection 
echo "Resetting iOS device connections..."
sudo killall -STOP -c usbd 2>/dev/null

# Reinstall plugins with fixes
echo "Applying fixes to plugins..."
./fix_flutter_web_auth.sh
./fix_permission_handler_errors.sh

# Clean Flutter
echo "Cleaning Flutter cache..."
flutter clean
flutter pub get

# Rebuild iOS
echo "Rebuilding iOS..."
cd ios/
pod install --repo-update
cd ..

echo "✅ Build environment reset complete"
echo ""
echo "To run the app on your device:"
echo "1. Unplug and replug your iPhone"
echo "2. Wait a few seconds for your Mac to recognize the device"
echo "3. Run: cd ios && open Runner.xcworkspace"
echo "4. In Xcode, select your device from the dropdown"
echo "5. Update the Bundle Identifier to 'com.mfchoudhury.fundracerapp'"
echo "6. Under Signing & Capabilities, select your Apple ID"
echo "7. Click the Run button" 