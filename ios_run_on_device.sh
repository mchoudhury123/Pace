#!/bin/bash

echo "Preparing iOS app for device testing..."

# Apply all necessary plugin fixes
echo "Applying flutter web auth fix..."
chmod +x fix_flutter_web_auth.sh
./fix_flutter_web_auth.sh

echo "Applying permission handler fixes..."
chmod +x fix_permission_handler_errors.sh
./fix_permission_handler_errors.sh

# Clean iOS build artifacts
echo "Cleaning iOS project..."
cd ios/
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*

# Update bundle identifier
echo "Updating bundle identifier..."
BUNDLE_ID="com.mfchoudhury.fundracerapp" # No hyphens, uses dots instead

# Install pods
echo "Installing pods..."
pod install --repo-update

echo "Opening Xcode. Please follow these steps to run on your device:"
echo "1. Connect your device"
echo "2. In the Xcode toolbar, select your device from the device dropdown"
echo "3. Click on Runner in the left sidebar"
echo "4. Go to the 'Signing & Capabilities' tab"
echo "5. Check 'Automatically manage signing'"
echo "6. Select your Apple ID account as the Team"
echo "7. Click the Run button (▶️) to build and run on your device"

# Open Xcode
open Runner.xcworkspace 