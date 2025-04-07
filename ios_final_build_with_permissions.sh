#!/bin/bash
set -e

# Clean and reinstall pods
cd ios
rm -rf Pods Podfile.lock
pod install

# Set environment variables for the build
export COMPILATION_MODE=wholemodule
export EXTENSION=1

# Build the app
xcodebuild clean build \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  GCC_PREPROCESSOR_DEFINITIONS='$GCC_PREPROCESSOR_DEFINITIONS EXTENSION=1 COCOAPODS=1 OPENSSL_NO_ASM=1'

echo "=== iOS build completed ==="
