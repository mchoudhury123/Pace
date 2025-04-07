#!/bin/bash

echo "Starting final build with Firebase dependency cycle fix..."
cd ios

# Clean and reinstall pods
echo "Cleaning and reinstalling CocoaPods..."
pod deintegrate
rm -rf Pods Podfile.lock
pod install

# Set environment variables
export EXCLUDED_ARCHS="i386 armv7"

# Run the build command with excluded archs
echo "Building iOS app..."
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos -allowProvisioningUpdates build

echo "iOS build completed."
