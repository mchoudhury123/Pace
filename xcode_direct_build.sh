#!/bin/bash

# Clean build
rm -rf ios/build

# Set build flags to avoid nesting
export COPY_PHASE_STRIP=YES
export STRIP_INSTALLED_PRODUCT=YES
export APPLICATION_EXTENSION_API_ONLY=YES

cd ios
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
  COPY_PHASE_STRIP=YES \
  STRIP_INSTALLED_PRODUCT=YES \
  APPLICATION_EXTENSION_API_ONLY=YES \
  build

echo "Direct Xcode build completed."
echo "You can find the built app at: ios/build/DerivedData/Build/Products/Release-iphoneos/Runner.app"
