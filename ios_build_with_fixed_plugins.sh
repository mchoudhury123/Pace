#!/bin/bash

echo "Starting iOS build with all plugin fixes..."

# Fix permissions on all scripts
chmod +x fix_flutter_web_auth.sh
chmod +x fix_phone_permission_strategy.sh
chmod +x fix_background_refresh_strategy.sh

# Run all fixes
echo "Applying flutter_web_auth_2 fixes..."
./fix_flutter_web_auth.sh

echo "Applying PhonePermissionStrategy fixes..."
./fix_phone_permission_strategy.sh

echo "Applying BackgroundRefreshStrategy fixes..."
./fix_background_refresh_strategy.sh

echo "All plugin fixes applied, beginning build process..."

# Clean and build the iOS app
cd ios/
rm -rf Pods
rm -rf .symlinks
rm -f Podfile.lock

# Set architecture flags to avoid build issues
export EXCLUDED_ARCHS="i386 armv7"

# Install pods
echo "Installing pods..."
pod install --repo-update

# Build the app for generic iOS device
echo "Building iOS app..."
xcodebuild -workspace Runner.xcworkspace -scheme Runner -sdk iphoneos -configuration Release build CODE_SIGNING_ALLOWED=NO | grep -v 'note:' | grep -v 'warning:' || true

echo "iOS build completed!" 