#!/bin/bash

# This approach bypasses Flutter's build process to avoid nesting issues
cd ios

# First ensure there are no nested apps from previous builds
find .. -name "*.app" -type d -path "*Runner.app/*Runner.app*" -exec rm -rf {} \; 2>/dev/null || true

# Clean the build directory
rm -rf build

# Run direct xcodebuild command (this avoids Flutter's build process which may be causing nesting)
xcodebuild \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build/DerivedData \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="arm64" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

echo "Direct Xcode build completed!"
echo "You can find the built app at: ios/build/DerivedData/Build/Products/Release-iphoneos/Runner.app"
