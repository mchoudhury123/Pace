#!/bin/bash

echo "=== Starting iOS final build ==="

# Set environment variables for building
export EXCLUDED_ARCHS=i386
export OTHER_CFLAGS="-DBORINGSSL_PREFIX=GRPC -DOPENSSL_NO_ASM -DEXTENSION=0"

# Clean Pods installation
cd ios
rm -rf Pods
rm -rf Podfile.lock

# Install pods
echo "Installing pods..."
pod install

# Build the app
echo "Building the iOS app..."
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release \
  -sdk iphoneos \
  COMPILATION_MODE=wholemodule \
  GCC_PREPROCESSOR_DEFINITIONS="EXTENSION=0 COCOAPODS=1 OPENSSL_NO_ASM=1" \
  OTHER_CFLAGS="-DBORINGSSL_PREFIX=GRPC -DOPENSSL_NO_ASM -DEXTENSION=0" \
  EXCLUDED_ARCHS=i386 \
  build

echo "=== iOS build completed ==="
