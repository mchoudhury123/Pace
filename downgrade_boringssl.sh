#!/bin/bash

# This script uses a downgraded version of BoringSSL-GRPC without the -G flag issue

echo "=== BUILDING WITH DOWNGRADED BORINGSSL-GRPC ==="

# Clean the project
echo "Cleaning the project..."
flutter clean
flutter pub get

# Clean iOS build
echo "Cleaning iOS build..."
cd ios
rm -rf Pods
rm -f Podfile.lock
rm -rf build
rm -rf DerivedData

# Run pod install with the downgraded version
echo "Running pod install..."
pod install

# Double-check for any -G flags
echo "Removing any -G flags from configuration files..."
find Pods -name "*.xcconfig" -exec sed -i '' 's/-G//g' {} \;
find Pods -name "*.pbxproj" -exec sed -i '' 's/-G//g' {} \;

# Build the app
cd ..
echo "Building iOS app..."
flutter build ios --no-codesign 