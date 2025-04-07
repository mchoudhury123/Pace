#!/bin/bash

echo "Starting iOS build and deployment to physical device..."
DEVICE_ID="00008130-00065CE92110001C"
TEAM_EMAIL="mfchoudhury@icloud.com"

# First, get the Team ID from the team name
echo "Looking up Development Team ID for $TEAM_EMAIL..."
cd ios

# Clean previous build artifacts
echo "Cleaning previous build artifacts..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
rm -rf Pods/
rm -rf .symlinks/
rm -f Podfile.lock

# Reinstall pods
echo "Reinstalling pods..."
pod install --repo-update

# If team ID is not found, prompt user to check Xcode and run manually
echo "Building and deploying to your iPhone..."
echo "Using Device ID: $DEVICE_ID"

# Run xcodebuild with automatic provisioning
# Using Debug configuration instead of Release to avoid dyld_shared_cache_extract_dylibs issue
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Debug \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="iPhone Developer" \
  DEVELOPMENT_TEAM=`security find-identity -p codesigning -v | grep "$TEAM_EMAIL" | head -1 | awk '{print $2}' | cut -d '(' -f 2 | cut -d ')' -f 1` \
  clean build

# Check if build was successful
if [ $? -eq 0 ]; then
  echo "✅ Build and deployment successful!"
  echo "Check your device to see the app. You may need to trust the developer certificate:"
  echo "Settings > General > Device Management > $TEAM_EMAIL > Trust"
else
  echo "❌ Build failed. Please try opening Xcode and deploying manually:"
  echo "1. cd ios && open Runner.xcworkspace"
  echo "2. Select your device from the device dropdown"
  echo "3. Go to Signing & Capabilities, select your team, and enable automatic signing"
  echo "4. Click the Run button to build and deploy"
fi 